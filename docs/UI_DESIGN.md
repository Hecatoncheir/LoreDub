# LoreDub UI design

## Direction

LoreDub should feel like a compact voice-processing instrument rather than a
generic gaming dashboard. The interface borrows the clarity and tactility of
industrial audio hardware without reproducing any existing product. Controls
are sparse, labelled, and visually connected to the signal flow.

## Visual system

Colour is a set of roles, not a palette. `LoreDubColors`
(`lib/src/ui/theme/tokens/lore_dub_colors.dart`) is a `ThemeExtension` that
every widget reads as `context.colors.<role>`; the raw values below live in
`LoreDubPalette` and no widget names them. The same roles carry the panel
that opens on a node of the scheme, answered there by that node's face, so
a widget standing in the panel is the widget of the window in another
colour — which is why a colour named in a widget cannot be repainted and
`tool/ratchet.dart` holds that count at zero.

| Role | Light value | Purpose |
| --- | --- | --- |
| `canvas` | `#D4D1CA` | Window background; the ground a page stands on |
| `panel` | `#E9E6DF` | Equipment cards and navigation |
| `raised` | `#F7F5F0` | Inputs, raised controls, the surface a menu opens on |
| `ink` | `#171717` | The text itself, and a control that carries it |
| `mutedInk` | `#65645F` | The quieter half: a note, a unit, a name under a card |
| `outline` | `#9D9A93` | The hairline around a panel, a tile, a field |
| `strongOutline` | `#292927` | The same line where it must hold its own against the ink: the edge of a control the player can press |
| `accent` | `#FF4A16` | What the player chose, and the active signal |
| `accentStrong` | `#C92F00` | The accent where it has to hold its own against the paper |
| `onAccent` | `#171717` | What is written on the accent |
| `onAccentMuted` | `#CCF7F5F0` | Its quieter half |
| `deep` | `#292927` | A dark surface: a card of the cast, a node's head, a chosen chip |
| `onDeep` | `#F7F5F0` | What is written on the dark |
| `onDeepMuted` | `#AAF7F5F0` | Its quieter half |
| `success` | `#277A52` | Listening and installed states |
| `warning` | `#9A5A00` | Loading and setup-required states |
| `danger` | `#B42318` | Recoverable failures |
| `shadow` | `#22171717` | What is cast under a card that is lifted |

`LoreDubColors.dark` is that set turned over, picked by
`AppSettings.interfaceTheme` or, by default, by Windows. Three roles do not
simply swap: `deep` means the surface that contrasts with the ground, so on
the ink it is the pale one; `accentStrong` is darker against paper and
lighter against the ink; and the three states are lifted, being unreadable
on the ground at the values paper needs. The accent is the same orange
either way, so neither `onAccent` nor `onAccentLight` turns over — which is
why naming a colour in a widget, `Colors.white` as much as a palette entry,
is what the dark theme breaks.

Lettering is roles too. Material's own `TextTheme` carries the headings, the
running text and the three small ones a note is said in (`titleSmall`,
`bodySmall`, `labelSmall`); what Material has no name for — the markings of
an instrument — is `LoreDubTextStyles`, read as `context.textStyles`:

| Role | Purpose |
| --- | --- |
| `moduleNumber` | The numeral an area is known by, on the accent |
| `moduleLabel` | The name beside it, in capitals |
| `cardTitle` | What a tile or a node is called |
| `monoCaption` | A measured thing said under something else: seconds, megabytes, a count |
| `monoMarking` | A state said in capitals — ЗВУК ИГРЫ, НЕ ПОДКЛЮЧЕНО |

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
   it. Like Live, the page has a scheme for its other half, switched to by
   its title: the same canvas, with the screen where the line of text
   starts and the game's sound led only into the character detection,
   which tells the voice who was speaking.
3. **Signal path** is the same pipeline drawn as nodes on a dotted field: the
   six stages as cards in the model tiles' vocabulary, the route between
   them in orange, and the cards of the cast joined to it by dashed graphite:
   each of them takes a voice from the pipeline or from another card, and
   sends the lines read in it on to the mix, so a character is part of the
   path rather than an island beside it. A socket is hollow until something is
   attached and rings orange while a link that would land on it is being
   pulled; with the way in cut, every stage keeps its card, dimmed and
   marked. There is one route on this canvas — the game's sound through
   whisper — because there is one the engine runs from here; the screen's
   reading is drawn on the Screen page's own scheme. The
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
- The graph screen's node panel stands down the right edge of the canvas,
  the whole height of it, and carries the face of the node it opened on —
  the same colours and the same icon, orange for the ends of the pipeline
  and dark for a card of the cast. It is that node's panel rather than a
  page the node opened.
- Every interactive control has a minimum 44–48 px target and visible keyboard
  focus supplied by the Material theme. The icon buttons packed into a tile's
  action band, a card's menu and the cross on a chip or a canvas card do not
  yet keep this (26–34 px); their sizes are `LoreDubTargets` in
  `lib/src/ui/theme.dart`, so they grow together when they do.
- Status is communicated with text and an indicator, never color alone.
- The sidebar names two groups — the dubbing (Live, Screen) and what is
  prepared before it (Characters, Glossary, Models, Settings) — so six entries
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
  the edge it sits on — and out again before the panel of the node clicked
  next comes in, so one node's settings are never seen dissolving into
  another's. The field of dots behind the scheme gives way to the
  cards — it parts around each of them, goes out as one comes over it rather
  than between two frames, closes again behind one that is taken off, and
  follows one that is dragged — which is the one piece of motion
  there that is not a change of state but the weight of what is on the
  canvas. It also lights towards a card the player has picked out: the nearer
  a dot stands to a chosen card the bigger it is drawn and the more of the
  orange it carries, which is the same orange its border is drawn in. The
  size is what carries it — colour alone, on dots this small, is barely
  there. Every one of these reads
  `MediaQuery.disableAnimationsOf` and is handed no duration at all where
  Windows says animation is off.
