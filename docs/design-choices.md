# Design choices

The options were drawn as live mockups using DESIGN.md tokens and the CloudShape formula, in the private
artifact <https://claude.ai/artifact/FJkxvUfx7uSzoyWaMRGqLY> (owner only; a copy is in
[`options.html`](options.html)). The user chose on 12 Oct 2026.

| Decision | Chosen | Not chosen |
|---|---|---|
| Name | **Tempo**: Italian for both "time" and "weather" (Pomodoro is Italian too), and pace in music. | Spell, Lull, Squall. |
| How the cloud morphs | **B · The cloud becomes the tool.** An hourglass while you focus (its sand runs down with the session), a ringing bell when time is up, a steaming mug on a short break, a sleepy crescent moon on a long one. It springs back to the cloud at rest and while paused. Skin, face, eyes, gaze and moods stay. | A · condense and puff (always the cloud: orb, puff, lounge, burst). C · rain it out (the cloud shrinks into a pool as the minutes go). |
| Panel | **A · The cloud in a ring.** 300 wide: the cloud inside a ring that drains (blue for focus, green for a break, amber while waiting for you), big minutes, the task (T), the session dots, Pause/Skip/Reset with keys, today's total. | B · two panes with a day timeline and the week. C · one slim strip. |
| Menu bar | **A · Cloud and minutes.** The template cloud plus "18′" (seconds only in the last minute); an amber dot while time is up and the next phase waits. | B · a cloud that drains. C · minutes only while running. |
| Sounds | **B · System sounds per event, plus weather while you focus.** Any of the eight system sounds for Focus starts, Focus ends, Break ends and Daily goal, a volume and one switch for all; plus an optional loop under focus (soft rain, distant storm, wind, brown noise) synthesized in the app, off by default. | A · system sounds only. C · B plus nimbi's own chimes. |
| App icon prop | **A · A ring of time.** An aurora arc three quarters of the way round the cloud. | B · a small hourglass. C · dial ticks. |

## Where things live

- **The morph is in NimbiKit** (0.5.0): `NimbiCloud(…, form: CloudForm, progress:)` with `.cloud`,
  `.hourglass`, `.bell`, `.mug`, `.moon`. Every form is 240 points clockwise from the top, so SwiftUI
  springs the outline point by point; the spring overshoots a little, which gives the squash and stretch.
  The hourglass's sand and the mug's steam come with their forms; the bell swings from its top.
- **The undo bar moved into NimbiKit** (`UndoBar`), since Tempo is the second app that needs one (Reset).
- **DESIGN.md** gained the lines these choices need: 3.5 (Tempo's cloud may take its tool's shape),
  10 (ambience the user turns on is not a notification) and 11.2 (Tempo's prop).

## The notch island (12 Oct 2026)

Options in the private artifact <https://claude.ai/artifact/6V8mn969Eu5hEo5aXRhRbW> (copy in
[`island-options.html`](island-options.html)); both recommended options were chosen.

| Decision | Chosen | Not chosen |
|---|---|---|
| Open island | **A · A ring on the right.** Cloud at 92 pt in its tool, TEMPO, a title ("Focus · 18 min left"), a subtitle (the task and end time), two actions, and 18.4's `ring` detail block with the minutes in it and "2 of 4" under it. The page format is unchanged, so it carries over to the shared island in phase 2. | B · the cloud inside its ring, big digits for the title (not in the page format). C · rows. |
| Closed island | **A · Cloud and minutes.** The cloud at 24 pt in its current tool, "18′" (seconds in the last minute), an amber dot when time is up. Same as the menu bar item. | B · cloud in a ring. C · a small ring with no digits. |

Phase 1 of 18.2, like Skyline's: Tempo never takes the notch on its own; **Use for Tempo** in settings
does, and **Give it to Relay** gives it back. The island window, its hover timing and the panel hanging
from it moved from Skyline into NimbiKit 0.6.0 (`NotchOwnership`, `NotchIsland`), so Tempo uses them
instead of copying. The page's words come from `IslandPage` in TempoCore, which is tested.

## Not built yet

- Notifications when the panel is closed and sounds are off. The amber dot and the cloud's mood carry it.
