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

## Not built yet

- The notch island page (DESIGN.md 18.4: glance "18′", detail `ring`). Until the shared island exists,
  Tempo never claims the notch; settings name the owner and say Tempo stays in the menu bar (18.2).
- Notifications when the panel is closed and sounds are off. The amber dot and the cloud's mood carry it.
