# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT
#
# The generation loop this replaces is the Qwen team's (Apache 2.0), in the
# `qwen_tts` package; what is here re-runs the same two models in the same
# order, and only the way each step is launched is ours.

"""Qwen3-TTS's generation loop, launched through CUDA graphs.

A frame of speech is sixteen codebook entries: the talker, a 1.7B model,
writes the first from the text and the frames before it, and its code
predictor, a small model, writes the fifteen after it one at a time. On
Windows that is where the time went: measured on an RTX 3080 Ti, a step of
the talker cost 49 ms and a step of the predictor 9, of which only a
fraction is arithmetic -- the rest is the launching of a few hundred small
kernels, which Windows' driver makes dear. Captured once into a CUDA graph
each, the same steps replay in 11 ms and 1 ms, so a frame that took 235 ms
takes about 30 and a line is read in a third of its own length rather than
three times it.

A graph replays fixed shapes over fixed memory, so both models run over
static caches -- the talker's long enough for the prompt and the longest
line, the predictor's for its sixteen positions -- and every step reads and
writes the same buffers, the mask among them: a position past the current
one is masked rather than cleared, so nothing is reset between frames or
lines. The rest of the loop is transformers' `generate` re-run by hand --
the repetition penalty, the suppressed tokens, the first two frames that may
not end the line, the same sampling in the same order -- and the prefill,
which runs once a line at a shape of its own, stays the model's own forward.
"""

import types

import torch


def _pick(logits, do_sample, top_k, top_p, temperature):
    """One token from [logits], the way transformers samples: temperature,
    then the hottest [top_k], then what falls within [top_p] of the mass;
    or the likeliest, without sampling."""
    if not do_sample:
        return logits.argmax(dim=-1)
    logits = logits.float() / max(float(temperature or 1.0), 1e-5)
    if top_k and 0 < top_k < logits.shape[-1]:
        lowest_kept = torch.topk(logits, top_k).values[..., -1, None]
        logits = logits.masked_fill(logits < lowest_kept, float("-inf"))
    if top_p is not None and top_p < 1.0:
        ordered, order = torch.sort(logits, descending=True)
        probabilities = torch.softmax(ordered, dim=-1)
        past = probabilities.cumsum(dim=-1) - probabilities > top_p
        ordered = ordered.masked_fill(past, float("-inf"))
        logits = torch.full_like(logits, float("-inf")).scatter(-1, order, ordered)
    return torch.multinomial(torch.softmax(logits, dim=-1), 1).squeeze(-1)


def _capture(run):
    """[run] captured into a CUDA graph: warmed up on a stream of its own,
    as the capture needs, and answered as (graph, what run returned)."""
    stream = torch.cuda.Stream()
    stream.wait_stream(torch.cuda.current_stream())
    with torch.cuda.stream(stream):
        for _ in range(2):
            run()
    torch.cuda.current_stream().wait_stream(stream)
    graph = torch.cuda.CUDAGraph()
    with torch.cuda.graph(graph):
        outputs = run()
    return graph, outputs


class FastTalker:
    """The talker's `generate`, one line at a time, over CUDA graphs."""

    # Room for the prompt -- the reference clip's codes, the text, the
    # speaker -- and the longest line the worker asks for.
    CACHE_LENGTH = 2048

    def __init__(self, talker):
        from transformers import StaticCache

        self._talker = talker
        self._predictor = talker.code_predictor
        self._device = next(talker.parameters()).device
        self._dtype = next(talker.parameters()).dtype
        self._groups = talker.config.num_code_groups
        hidden = talker.config.hidden_size
        self._cache = StaticCache(
            config=talker.config,
            max_cache_len=self.CACHE_LENGTH,
            device=self._device,
            dtype=self._dtype,
        )
        self._small_cache = StaticCache(
            config=self._predictor.config,
            max_cache_len=self._groups,
            device=self._device,
            dtype=self._dtype,
        )
        # What one step of the talker reads and writes.
        self._embeds = torch.zeros(1, 1, hidden, device=self._device, dtype=self._dtype)
        self._position = torch.zeros(1, device=self._device, dtype=torch.long)
        self._ids = torch.zeros(3, 1, 1, device=self._device, dtype=torch.long)
        self._span = torch.arange(self.CACHE_LENGTH, device=self._device)[None, None, None, :]
        self._mask = torch.zeros(1, 1, 1, self.CACHE_LENGTH, device=self._device, dtype=torch.bool)
        # What the predictor's steps read: the two vectors of its prefill,
        # then the token of each step after.
        self._pair = torch.zeros(1, 2, hidden, device=self._device, dtype=self._dtype)
        self._token = torch.zeros(1, 1, device=self._device, dtype=torch.long)
        self._small_position = torch.zeros(1, device=self._device, dtype=torch.long)
        self._small_span = torch.arange(self._groups, device=self._device)[None, None, None, :]
        self._small_mask = torch.zeros(
            1, 1, 1, self._groups, device=self._device, dtype=torch.bool
        )
        self._suppressed = None
        # Captured here, before any line: the capture runs both models over
        # the caches, and captured in the middle of a line it wrote over the
        # prompt the line had just prefilled.
        self._graphs = None
        self._captured()

    # -- the captured steps -------------------------------------------------

    def _talker_step(self):
        hidden = self._talker.model(
            inputs_embeds=self._embeds,
            past_key_values=self._cache,
            cache_position=self._position,
            position_ids=self._ids,
            attention_mask=self._mask,
            use_cache=True,
        ).last_hidden_state
        return hidden, self._talker.codec_head(hidden)

    def _predictor_prefill(self):
        embeds = self._predictor.small_to_mtp_projection(self._pair)
        hidden = self._predictor.model(
            inputs_embeds=embeds,
            past_key_values=self._small_cache,
            cache_position=torch.arange(2, device=self._device),
            position_ids=torch.arange(2, device=self._device).view(1, -1),
            attention_mask=self._small_mask,
            use_cache=True,
        ).last_hidden_state
        return self._predictor.lm_head[0](hidden[:, -1])

    def _predictor_step(self, step):
        embedders = self._predictor.model.get_input_embeddings()

        def run():
            embeds = self._predictor.small_to_mtp_projection(embedders[step - 1](self._token))
            hidden = self._predictor.model(
                inputs_embeds=embeds,
                past_key_values=self._small_cache,
                cache_position=self._small_position,
                position_ids=self._small_position.view(1, 1),
                attention_mask=self._small_mask,
                use_cache=True,
            ).last_hidden_state
            return self._predictor.lm_head[step](hidden[:, -1])

        return run

    def _captured(self):
        """The graphs, captured on the first line and kept."""
        if self._graphs is None:
            self._position.fill_(1)
            self._mask.copy_(self._span <= self._position)
            self._small_position.fill_(1)
            self._small_mask.copy_(self._small_span <= self._small_position)
            steps = [_capture(self._predictor_prefill)]
            for step in range(1, self._groups - 1):
                self._small_position.fill_(step + 1)
                self._small_mask.copy_(self._small_span <= self._small_position)
                steps.append(_capture(self._predictor_step(step)))
            self._graphs = (_capture(self._talker_step), steps)
        return self._graphs

    # -- the loop -----------------------------------------------------------

    def _frame(self, token, past_hidden, sampling):
        """The fifteen codes after [token] in this frame, and the frame's
        input to the talker: every code's embedding summed."""
        _, steps = self._captured()
        embedders = self._predictor.model.get_input_embeddings()
        last_id_hidden = self._talker.get_input_embeddings()(token)
        self._pair.copy_(torch.cat((past_hidden, last_id_hidden), dim=1))
        self._small_position.fill_(1)
        self._small_mask.copy_(self._small_span <= self._small_position)
        graph, logits = steps[0]
        graph.replay()
        codes = [_pick(logits.clone(), *sampling)]
        summed = last_id_hidden + embedders[0](codes[0].unsqueeze(1))
        for step in range(1, self._groups - 1):
            self._token.copy_(codes[-1].view(1, 1))
            self._small_position.fill_(step + 1)
            self._small_mask.copy_(self._small_span <= self._small_position)
            graph, logits = steps[step]
            graph.replay()
            codes.append(_pick(logits.clone(), *sampling))
            summed = summed + embedders[step](codes[-1].unsqueeze(1))
        codec_ids = torch.cat([token, torch.stack(codes, dim=1)], dim=-1)
        return codec_ids, summed

    def _processed(self, logits, generated, step, settings):
        """[logits] as transformers' processors leave them: the tokens said
        already penalized, the suppressed ones and -- for the first frames --
        the end of the line ruled out."""
        logits = logits.float()
        penalty = settings["repetition_penalty"]
        if generated and penalty != 1.0:
            said = torch.stack(generated, dim=1)
            scores = logits.gather(1, said)
            scores = torch.where(scores < 0, scores * penalty, scores / penalty)
            logits = logits.scatter(1, said, scores)
        if self._suppressed is not None:
            logits[:, self._suppressed] = float("-inf")
        if step < settings["min_new_tokens"]:
            logits[:, settings["eos_token_id"]] = float("-inf")
        return logits

    @torch.inference_mode()
    def generate(
        self,
        inputs_embeds,
        attention_mask=None,
        trailing_text_hidden=None,
        tts_pad_embed=None,
        max_new_tokens=4096,
        min_new_tokens=2,
        do_sample=True,
        top_k=50,
        top_p=1.0,
        temperature=0.9,
        subtalker_dosample=True,
        subtalker_top_k=50,
        subtalker_top_p=1.0,
        subtalker_temperature=0.9,
        eos_token_id=None,
        repetition_penalty=1.0,
        suppress_tokens=None,
        **_,
    ):
        talker = self._talker
        if eos_token_id is None:
            eos_token_id = talker.config.codec_eos_token_id
        self._suppressed = (
            torch.tensor(list(suppress_tokens), device=self._device) if suppress_tokens else None
        )
        settings = {
            "repetition_penalty": float(repetition_penalty),
            "min_new_tokens": int(min_new_tokens),
            "eos_token_id": int(eos_token_id),
        }
        sampling = (subtalker_dosample, subtalker_top_k, subtalker_top_p, subtalker_temperature)
        length = inputs_embeds.shape[1]
        limit = min(int(max_new_tokens), self.CACHE_LENGTH - length - 1)
        # The prompt, at its own shape: the model's own forward, which also
        # settles the rotary offsets the steps after it carry on from.
        prefilled = talker(
            inputs_embeds=inputs_embeds,
            attention_mask=attention_mask,
            past_key_values=self._cache,
            cache_position=torch.arange(length, device=self._device),
            use_cache=True,
            trailing_text_hidden=trailing_text_hidden,
            tts_pad_embed=tts_pad_embed,
        )
        logits = prefilled.logits[:, -1]
        past_hidden = prefilled.past_hidden
        rope_deltas = talker.rope_deltas.reshape(-1)
        frames = [((past_hidden.clone(),), None)]
        generated = []
        talker_graph = self._captured()[0][0]
        for step in range(limit):
            token = _pick(self._processed(logits, generated, step, settings), do_sample, top_k, top_p, temperature)
            if int(token) == settings["eos_token_id"]:
                break
            generated.append(token)
            codec_ids, summed = self._frame(token.view(1, 1), past_hidden, sampling)
            trailing = (
                trailing_text_hidden[:, step].unsqueeze(1)
                if trailing_text_hidden is not None and step < trailing_text_hidden.shape[1]
                else tts_pad_embed
            )
            self._embeds.copy_(summed + trailing)
            self._position.fill_(length + step)
            self._ids.copy_((self._position + rope_deltas).view(1, 1, 1).expand(3, 1, 1))
            self._mask.copy_(self._span <= self._position)
            talker_graph.replay()
            hidden, logits = self._captured()[0][1]
            past_hidden = hidden.clone()
            logits = logits[:, -1].clone()
            frames.append(((past_hidden,), codec_ids))
        return types.SimpleNamespace(hidden_states=frames)


def fast_generation(model):
    """Hangs the loop on [model]'s talker, where the card is there for it;
    on the processor the model's own loop stays, graphs being the card's."""
    talker = getattr(model, "talker", None)
    if talker is None or next(talker.parameters()).device.type != "cuda":
        return False
    fast = FastTalker(talker)
    talker.generate = fast.generate
    return True
