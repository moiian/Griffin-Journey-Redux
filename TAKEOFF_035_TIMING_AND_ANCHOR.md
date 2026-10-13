# Takeoff timing and gear-specific player position — 0.3.5

Automatic hover and sprint cannot cut the first 1.5 seconds after the takeoff action is observed. If the action is missed between frames, first valid airborne observation conservatively starts the timer. Pause/menu/photo time is excluded. Valid airborne flags are still required for automatic handoff.

RT/RB/LB pressed during this interval queue gear 2; LT replaces that selection with gear 1 hover. Holding movement/A/Y continues into gear 1 after the wait without releasing. Existing native action cooldown still applies. RS native landing and explicit external takeover retain their cancellation behavior.

In gear 1, the player's real Transform, position context and collision controller use the player position calculated from seat preset [1], including anchor/offset/body-tilt position parameters. Stick input does not apply spherical navigation. The selected visual/Hip layout and passenger slots remain independent; preset selection is not changed.

Entering gear 2 through RT, RB or LB restores the original spherical player navigation in that frame. Returning through LT uses preset [1] again. External action tool behavior is retained.

Offline checks cover the playback minimum, queued inputs, pause exclusion, continuous input, nonzero/live preset offsets, physical layers, visual preset retention and same-frame navigation changes. End driving and Reset scripts; confirm v0.3.5. Native animation timing and visual feel still require in-game acceptance.
