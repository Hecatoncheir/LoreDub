# LoreDub UI design

## Direction

LoreDub should feel like a compact voice-processing instrument rather than a
generic gaming dashboard. The interface borrows the clarity and tactility of
industrial audio hardware without reproducing any existing product. Controls
are sparse, labelled, and visually connected to the signal flow.

## Visual system

| Token | Value | Purpose |
| --- | --- | --- |
| Ink | `#171717` | Primary text and high-contrast controls |
| Graphite | `#292927` | Selected navigation and signal surfaces |
| Canvas | `#D4D1CA` | Window background |
| Panel | `#E9E6DF` | Equipment cards and navigation |
| Raised | `#F7F5F0` | Inputs and raised controls |
| Orange | `#FF4A16` | Primary action and active signal |
| Success | `#277A52` | Listening and installed states |
| Warning | `#9A5A00` | Loading and setup-required states |
| Error | `#B42318` | Recoverable failures |

The type system has three voices, bundled as static instances cut from the
upstream variable fonts so the weights are real and Cyrillic ships with them:

| Face | Where | Why |
| --- | --- | --- |
| Nunito | Page titles, product name | Rounded, matching the soft moulded shell of the icon |
| Nunito Sans | Everything the user reads | Same family, wider and calmer at text sizes |
| JetBrains Mono | Module numbers and labels, breadcrumb, strap lines, measured times | The instrument markings; monospaced digits keep latencies from twitching |

Small uppercase module labels provide the technical character; Russian labels
remain plain and readable. Cards use one outline weight and a restrained 12 px
radius.

## Information architecture

1. **Live voice** is the default workspace. Game selection and the single main
   start/stop action are grouped as `01 / GAME INPUT`; translated dialogue is
   grouped as `02 / LIVE TRANSCRIPT`. Between them, while the session cannot
   start, one card numbers what is still missing — packages, a route taken
   apart on the graph, a game not yet chosen — each step leading to the
   screen it is done on, so a disabled start button never has to be guessed
   at. It is drawn from `stepsBeforeStart`, which reads the same
   `ModelSelection` the button's own `canStart` does.
2. **Screen text** is the other half of the work, on a page of its own: the
   frame the subtitles are read out of, drawn on a picture of the game's
   window, beside the controls that start the session -- and under them two
   lists, what the frame gained and what the player picked out by hand. One
   session answers both, so the frame belongs here rather than in the
   settings: it is part of the work this page does, and nothing else reads
   it.
3. **Signal path** is the same pipeline drawn as nodes on a dotted field: the
   six stages as cards in the model tiles' vocabulary, the route between
   them in orange, and the cards of the cast joined to it by dashed graphite:
   each of them takes a voice from the pipeline or from another card, and
   sends the lines read in it on to the mix, so a character is part of the
   path rather than an island beside it. A socket is hollow until something is
   attached and rings orange while a link that would land on it is being
   pulled; with the way in cut, every stage keeps its card, dimmed and
   marked. There is one route on this canvas — the game's sound through
   whisper — because there is one the engine runs from here. The
   canvas carries no settings of its own — a node's own panel floats over it
   and writes into the same places the other screens do — and the panel is
   floated rather than docked so opening it never moves the scheme out from
   under the pointer that opened it.
4. **Model bank** shows installation state, download progress, and recovery
   errors without mixing them into the live controls. The Whisper builds are a
   size-against-quality chart (`whisper_model_chart.dart`): bar height is the
   download to scale, and a bar is light when missing, ticked when downloaded,
   graphite with an orange edge when in use, and fills from the bottom while it
   downloads. Each bar keeps its buttons (download, pause/resume and cancel, or
   delete) always visible at its foot and grows slightly under the pointer;
   only a failure's wording goes to a row under the chart. The dubbing
   languages and the voice converter are tiles in the same vocabulary
   (`model_tiles.dart`): one tile per language holds its translator and voice,
   downloaded, picked and deleted as a pair with one ring for both. The shared
   pieces — buttons, ring, hover growth, the delete dialog — live in
   `model_visuals.dart`. The Compute device card in Settings uses the same
   states for its stage-by-device table and GPU package tiles
   (`compute_matrix.dart`).
5. **Signal setup** is four named groups, announced by the same numbered
   module label the other screens mark their areas with: the interface
   (language and hotkeys, which are the player's own way in), dubbing
   (original volume, speech speed, voice), compute — one card, which names
   the adapter under GPU, asks for the thread count under CPU, and says
   neither under Automatic, the table of stage by device being the answer
   either line would have given — and a fourth folded away behind its
   heading — the Python path, the download proxy and the model directory,
   which are changed when something is broken rather than while playing. What the pipeline reads is not among them: Live dubs the game's
   sound and the Screen page reads the screen, and each carries the controls
   for its own work. Settings are disabled while the pipeline is active.

## Interaction rules

- One orange primary action per workspace; secondary actions use outlines.
- Every interactive control has a minimum 44–48 px target and visible keyboard
  focus supplied by the Material theme.
- Status is communicated with text and an indicator, never color alone.
- The sidebar names two groups — the dubbing (Live, Snippet) and what is
  prepared before it (Characters, Graph, Models, Settings) — so six entries
  do not read as six equal ways in. The compact navigation indexes into
  `DashboardSection.values` and carries no headings.
- At widths below 900 px the sidebar becomes bottom navigation. The game-source
  controls stack below 720 px to avoid horizontal overflow.
- Motion is limited to a 180 ms content transition when switching workspaces;
  there is no decorative continuous animation. The graph screen answers an
  edit with motion of its own — all of it under 300 ms, all of it started by
  something the player did, none of it running on its own: a line drawn grows
  out of the socket it leaves, a line cut fades where it lay, a card arrives
  on the canvas and goes off it rather than blinking on and off, a card going
  dark or gaining an orange head eases into it, and the panel comes in from
  the edge it sits on. The field of dots behind the scheme gives way to the
  cards — it parts around each of them, goes out as one comes over it rather
  than between two frames, closes again behind one that is taken off, and
  follows one that is dragged — which is the one piece of motion
  there that is not a change of state but the weight of what is on the
  canvas. It also lights towards a card the player has picked out: the nearer
  a dot stands to a chosen card the more of the orange it carries, which is
  the same orange its border is drawn in. Every one of these reads
  `MediaQuery.disableAnimationsOf` and is handed no duration at all where
  Windows says animation is off.
