# Copyright (c) 2026 LoreDub contributors.
# SPDX-License-Identifier: MIT
#
# The network below is the tone colour converter of OpenVoice V2, cut down to
# the parts voice conversion runs: the posterior encoder, the flow, the
# decoder and the reference encoder that turns a voice into an embedding.
# OpenVoice is Copyright (c) 2024 MyShell.ai and released under the MIT
# licence: https://github.com/myshell-ai/OpenVoice

"""Re-voices synthesized speech in the timbre of a reference recording.

Only torch and numpy are needed, which is all the bundled runtime ships:
the spectrogram is torch.stft and resampling is done in the frequency domain
rather than through librosa.
"""

import json
import pathlib
import warnings

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

# The checkpoint names its weight-normalised layers the way the legacy helper
# does (weight_g / weight_v), so that helper is the one that loads it.
from torch.nn.utils import weight_norm

LRELU_SLOPE = 0.1


def _padding(kernel_size, dilation=1):
    return (kernel_size * dilation - dilation) // 2


def _sequence_mask(length, max_length):
    positions = torch.arange(max_length, dtype=length.dtype, device=length.device)
    return positions.unsqueeze(0) < length.unsqueeze(1)


def resample(samples, rate, target):
    """Band-limited resampling of a whole clip through its spectrum.

    The clips are a few seconds long, so one FFT each way is cheap and needs
    nothing beyond numpy.
    """
    samples = np.asarray(samples, dtype=np.float32)
    if rate == target or samples.size == 0:
        return samples
    count = max(1, int(round(samples.size * target / rate)))
    spectrum = np.fft.rfft(samples)
    kept = np.zeros(count // 2 + 1, dtype=np.complex128)
    shared = min(kept.size, spectrum.size)
    kept[:shared] = spectrum[:shared]
    return (np.fft.irfft(kept, count) * (count / samples.size)).astype(np.float32)


class _WN(nn.Module):
    def __init__(self, hidden_channels, kernel_size, dilation_rate, n_layers, gin_channels):
        super().__init__()
        self.hidden_channels = hidden_channels
        self.n_layers = n_layers
        self.in_layers = nn.ModuleList()
        self.res_skip_layers = nn.ModuleList()
        self.cond_layer = weight_norm(
            nn.Conv1d(gin_channels, 2 * hidden_channels * n_layers, 1), name="weight"
        )
        for index in range(n_layers):
            dilation = dilation_rate**index
            self.in_layers.append(
                weight_norm(
                    nn.Conv1d(
                        hidden_channels,
                        2 * hidden_channels,
                        kernel_size,
                        dilation=dilation,
                        padding=_padding(kernel_size, dilation),
                    ),
                    name="weight",
                )
            )
            channels = 2 * hidden_channels if index < n_layers - 1 else hidden_channels
            self.res_skip_layers.append(
                weight_norm(nn.Conv1d(hidden_channels, channels, 1), name="weight")
            )

    def forward(self, x, x_mask, g):
        output = torch.zeros_like(x)
        g = self.cond_layer(g)
        width = self.hidden_channels
        for index in range(self.n_layers):
            offset = index * 2 * width
            acts = self.in_layers[index](x) + g[:, offset : offset + 2 * width, :]
            acts = torch.tanh(acts[:, :width]) * torch.sigmoid(acts[:, width:])
            res_skip = self.res_skip_layers[index](acts)
            if index < self.n_layers - 1:
                x = (x + res_skip[:, :width]) * x_mask
                output = output + res_skip[:, width:]
            else:
                output = output + res_skip
        return output * x_mask


class _ResBlock(nn.Module):
    def __init__(self, channels, kernel_size, dilation):
        super().__init__()
        self.convs1 = nn.ModuleList(
            weight_norm(
                nn.Conv1d(
                    channels, channels, kernel_size, 1, dilation=d, padding=_padding(kernel_size, d)
                )
            )
            for d in dilation
        )
        self.convs2 = nn.ModuleList(
            weight_norm(
                nn.Conv1d(channels, channels, kernel_size, 1, dilation=1, padding=_padding(kernel_size))
            )
            for _ in dilation
        )

    def forward(self, x):
        for first, second in zip(self.convs1, self.convs2):
            step = first(F.leaky_relu(x, LRELU_SLOPE))
            step = second(F.leaky_relu(step, LRELU_SLOPE))
            x = step + x
        return x


class _Generator(nn.Module):
    def __init__(
        self,
        initial_channel,
        resblock_kernel_sizes,
        resblock_dilation_sizes,
        upsample_rates,
        upsample_initial_channel,
        upsample_kernel_sizes,
        gin_channels,
    ):
        super().__init__()
        self.num_kernels = len(resblock_kernel_sizes)
        self.conv_pre = nn.Conv1d(initial_channel, upsample_initial_channel, 7, 1, padding=3)
        self.ups = nn.ModuleList()
        for index, (rate, kernel) in enumerate(zip(upsample_rates, upsample_kernel_sizes)):
            self.ups.append(
                weight_norm(
                    nn.ConvTranspose1d(
                        upsample_initial_channel // (2**index),
                        upsample_initial_channel // (2 ** (index + 1)),
                        kernel,
                        rate,
                        padding=(kernel - rate) // 2,
                    )
                )
            )
        self.resblocks = nn.ModuleList()
        channels = upsample_initial_channel
        for index in range(len(self.ups)):
            channels = upsample_initial_channel // (2 ** (index + 1))
            for kernel, dilation in zip(resblock_kernel_sizes, resblock_dilation_sizes):
                self.resblocks.append(_ResBlock(channels, kernel, dilation))
        self.conv_post = nn.Conv1d(channels, 1, 7, 1, padding=3, bias=False)
        self.cond = nn.Conv1d(gin_channels, upsample_initial_channel, 1)

    def forward(self, x, g):
        x = self.conv_pre(x) + self.cond(g)
        for index, up in enumerate(self.ups):
            x = up(F.leaky_relu(x, LRELU_SLOPE))
            blocks = self.resblocks[index * self.num_kernels : (index + 1) * self.num_kernels]
            x = sum(block(x) for block in blocks) / self.num_kernels
        return torch.tanh(self.conv_post(F.leaky_relu(x)))


class _PosteriorEncoder(nn.Module):
    def __init__(self, in_channels, out_channels, hidden_channels, kernel_size, dilation_rate, n_layers, gin_channels):
        super().__init__()
        self.out_channels = out_channels
        self.pre = nn.Conv1d(in_channels, hidden_channels, 1)
        self.enc = _WN(hidden_channels, kernel_size, dilation_rate, n_layers, gin_channels)
        self.proj = nn.Conv1d(hidden_channels, out_channels * 2, 1)

    def forward(self, x, x_lengths, g, tau):
        x_mask = _sequence_mask(x_lengths, x.size(2)).unsqueeze(1).to(x.dtype)
        x = self.enc(self.pre(x) * x_mask, x_mask, g)
        mean, log_scale = torch.split(self.proj(x) * x_mask, self.out_channels, dim=1)
        z = (mean + torch.randn_like(mean) * tau * torch.exp(log_scale)) * x_mask
        return z, x_mask


class _CouplingLayer(nn.Module):
    """A mean-only residual coupling layer, the only kind the flow uses."""

    def __init__(self, channels, hidden_channels, kernel_size, dilation_rate, n_layers, gin_channels):
        super().__init__()
        self.half = channels // 2
        self.pre = nn.Conv1d(self.half, hidden_channels, 1)
        self.enc = _WN(hidden_channels, kernel_size, dilation_rate, n_layers, gin_channels)
        self.post = nn.Conv1d(hidden_channels, self.half, 1)

    def forward(self, x, x_mask, g, reverse):
        first, second = torch.split(x, [self.half] * 2, 1)
        shift = self.post(self.enc(self.pre(first) * x_mask, x_mask, g)) * x_mask
        second = (second - shift) * x_mask if reverse else shift + second * x_mask
        return torch.cat([first, second], 1)


class _Flip(nn.Module):
    """Holds a place in the flow so the checkpoint's layer numbers line up."""

    def forward(self, x):
        return torch.flip(x, [1])


class _Flow(nn.Module):
    def __init__(self, channels, hidden_channels, kernel_size, dilation_rate, n_layers, gin_channels, n_flows=4):
        super().__init__()
        self.flows = nn.ModuleList()
        for _ in range(n_flows):
            self.flows.append(
                _CouplingLayer(channels, hidden_channels, kernel_size, dilation_rate, n_layers, gin_channels)
            )
            self.flows.append(_Flip())

    def forward(self, x, x_mask, g, reverse=False):
        for flow in reversed(self.flows) if reverse else self.flows:
            x = flow(x, x_mask, g, reverse) if isinstance(flow, _CouplingLayer) else flow(x)
        return x


class _ReferenceEncoder(nn.Module):
    def __init__(self, spec_channels, gin_channels):
        super().__init__()
        self.spec_channels = spec_channels
        filters = [1, 32, 32, 64, 64, 128, 128]
        self.convs = nn.ModuleList(
            weight_norm(
                nn.Conv2d(filters[i], filters[i + 1], kernel_size=(3, 3), stride=(2, 2), padding=(1, 1))
            )
            for i in range(len(filters) - 1)
        )
        width = spec_channels
        for _ in range(len(filters) - 1):
            width = (width - 3 + 2) // 2 + 1
        self.gru = nn.GRU(input_size=filters[-1] * width, hidden_size=128, batch_first=True)
        self.proj = nn.Linear(128, gin_channels)
        self.layernorm = nn.LayerNorm(spec_channels)

    def forward(self, inputs):
        batch = inputs.size(0)
        out = self.layernorm(inputs.view(batch, 1, -1, self.spec_channels))
        for conv in self.convs:
            out = F.relu(conv(out))
        out = out.transpose(1, 2)
        out = out.contiguous().view(batch, out.size(1), -1)
        self.gru.flatten_parameters()
        _, out = self.gru(out)
        return self.proj(out.squeeze(0))


class _Converter(nn.Module):
    def __init__(self, spec_channels, model):
        super().__init__()
        if str(model.get("resblock", "1")) != "1":
            raise ValueError("only the ResBlock1 decoder of OpenVoice V2 is supported")
        gin = model["gin_channels"]
        inter = model["inter_channels"]
        hidden = model["hidden_channels"]
        self.dec = _Generator(
            inter,
            model["resblock_kernel_sizes"],
            model["resblock_dilation_sizes"],
            model["upsample_rates"],
            model["upsample_initial_channel"],
            model["upsample_kernel_sizes"],
            gin,
        )
        self.enc_q = _PosteriorEncoder(spec_channels, inter, hidden, 5, 1, 16, gin)
        self.flow = _Flow(inter, hidden, 5, 1, 4, gin)
        self.ref_enc = _ReferenceEncoder(spec_channels, gin)
        self.zero_g = bool(model.get("zero_g", False))

    def recolour(self, spec, lengths, source, target, tau):
        z, mask = self.enc_q(spec, lengths, torch.zeros_like(source) if self.zero_g else source, tau)
        z = self.flow(z, mask, source)
        z = self.flow(z, mask, target, reverse=True)
        return self.dec(z * mask, torch.zeros_like(target) if self.zero_g else target)


class ToneConverter:
    """Loads the converter once and re-voices clips with it."""

    def __init__(self, directory, device):
        directory = pathlib.Path(directory)
        config = json.loads((directory / "config.json").read_text(encoding="utf-8"))
        data = config["data"]
        self.rate = int(data["sampling_rate"])
        self.n_fft = int(data["filter_length"])
        self.hop = int(data["hop_length"])
        self.win = int(data["win_length"])
        self.device = device
        with warnings.catch_warnings():
            # torch deprecated this weight_norm, but it is the one whose
            # parameter names the checkpoint was saved under.
            warnings.simplefilter("ignore", FutureWarning)
            net = _Converter(self.n_fft // 2 + 1, config["model"])
        state = torch.load(directory / "checkpoint.pth", map_location="cpu", weights_only=True)
        missing, _ = net.load_state_dict(state["model"], strict=False)
        if missing:
            raise RuntimeError(f"the voice converter checkpoint lacks {len(missing)} weights, {missing[0]} first")
        self.net = net.to(device).eval()
        self._window = torch.hann_window(self.win).to(device)

    def _spectrogram(self, samples):
        signal = torch.from_numpy(np.ascontiguousarray(samples, dtype=np.float32)).to(self.device)
        pad = (self.n_fft - self.hop) // 2
        signal = F.pad(signal.view(1, 1, -1), (pad, pad), mode="reflect").view(1, -1)
        spec = torch.stft(
            signal,
            self.n_fft,
            hop_length=self.hop,
            win_length=self.win,
            window=self._window,
            center=False,
            normalized=False,
            onesided=True,
            return_complex=True,
        )
        return torch.sqrt(spec.real.pow(2) + spec.imag.pow(2) + 1e-6)

    def embed(self, samples, rate):
        """The timbre of a recording, as the embedding the converter aims at."""
        audio = resample(samples, rate, self.rate)
        with torch.inference_mode():
            return self.net.ref_enc(self._spectrogram(audio).transpose(1, 2)).unsqueeze(-1)

    def convert(self, samples, rate, target, tau=0.3):
        """The clip re-voiced in [target]'s timbre, at the converter's own rate."""
        audio = resample(samples, rate, self.rate)
        with torch.inference_mode():
            spec = self._spectrogram(audio)
            source = self.net.ref_enc(spec.transpose(1, 2)).unsqueeze(-1)
            lengths = torch.LongTensor([spec.size(-1)]).to(self.device)
            converted = self.net.recolour(spec, lengths, source, target, tau)
        return np.clip(converted[0, 0].float().cpu().numpy(), -1.0, 1.0), self.rate
