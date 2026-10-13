# Shared camera-follow policy — 0.2.7

Gear 1 follows only while the Griffin's eased body yaw is still rotating. Idle hover, straight forward/backward movement and vertical movement do not trigger following. Once body rotation settles, the camera leaves any remaining lag instead of continuing to catch up. Low-speed body steering and movement are unchanged.

Both gears now call one shared camera core for native-angle calibration, shortest-arc rate-limited easing, small right-stick blending, large-input takeover, the configured manual threshold, 0.08 hysteresis and 0.8-second recovery delay. Gear 2 keeps its previous input trigger and behavior. Gear 1 uses actual body-turn velocity as its trigger. The two speed settings remain independent and existing values are loaded unchanged. Right-stick input is read for gear 1 even when the gear 2 follow toggle is off.

Exact current-player/controller checks, horizontal-only writes, original/head-position camera compatibility, pause/release and camera-only error isolation are preserved. No new AI or gameplay control is added.

All 22 Lua54 files and existing gameplay/protection/settings/Debug-absent/default-no-diagnostics regressions pass. Low-speed tests cover rotation-only gating, no idle/straight/climb catch-up, shared manual blending, threshold changes, hysteresis/recovery timing, independent speed/zero/save/reload, native units, exact scope and release. A differential test against saved actual 0.2.6 camera source matches gear 2 output and diagnostics over 2,000 simulated frames in radians/degrees with input, manual takeover, hysteresis, recovery and live speed/threshold changes. These are offline checks; native handling remains subject to in-game acceptance.

End driving, Reset scripts and verify v0.2.7. Turn at low speed, then release and observe that following stops when body turning stops. During another turn, use the right stick past the takeover threshold and check delayed recovery after release. Speed sliders are separate; the manual threshold is shared.
