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
   grouped as `02 / LIVE TRANSCRIPT`.
2. **Model bank** shows installation state, download progress, and recovery
   errors without mixing them into the live controls.
3. **Signal setup** contains capture mode, OCR region, original volume, speech
   speed, and CPU budget. Settings are disabled while the pipeline is active.

## Interaction rules

- One orange primary action per workspace; secondary actions use outlines.
- Every interactive control has a minimum 44–48 px target and visible keyboard
  focus supplied by the Material theme.
- Status is communicated with text and an indicator, never color alone.
- At widths below 900 px the sidebar becomes bottom navigation. The game-source
  controls stack below 720 px to avoid horizontal overflow.
- Motion is limited to a 180 ms content transition when switching workspaces;
  there is no decorative continuous animation.
