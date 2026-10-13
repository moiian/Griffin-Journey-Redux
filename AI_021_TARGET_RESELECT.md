# Griffin Journey Redux 0.2.1: retarget before action requests

Every committed Griffin action first selects the current player through the existing ManualPlayer/setTarget interface, then immediately submits the requested action in the same behavior callback. This includes manual flight commands, automatic hover, external driving commands, and non-driving single-action bridge requests. There is one target selection per actual action request; no continuous retarget loop or transition action is added.

The existing action nodes, 0.35-second request interval, instance ownership, settings, anti-jitter, seats and camera remain unchanged. Paused, cancelled, replaced or stale requests do not retarget. If target selection fails, the action is not submitted. Passenger animation requests are outside this change.

All 20 Lua54 files compile. Full gameplay and anti-jitter regressions, developer/player package checks and default no-diagnostic-output checks pass. New regressions verify exact target/action order, movement and hover, one retarget per request, cooldown, pause, replacement, reset, ownership, target failure and the non-driving bridge. These checks do not establish native AI behavior.

After reloading scripts, use normal driving, switch between movement and hover, then resume movement. Observe whether the next action still briefly follows an autonomous target before player steering resumes. No diagnostic recording or additional toggle is required. In-game AI effectiveness remains unverified.
