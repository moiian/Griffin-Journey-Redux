# Measured sprint momentum into hover — 0.3.6

Takeoff's minimum unpaused playback delay is now **1.89 seconds**.

Gear 2 samples the retained Griffin's Universal position once per behavior frame while its native WrapAround action is active. A short time-based filter estimates the world velocity vector. Flight Settings displays measured total/horizontal/signed-vertical speed. Sampling only uses Lua state and native reads; it does not save logs or change native sprint movement.

LT retains the latest valid velocity, continues sampling while the native sprint is still active during the transition, and starts code-driven exponential coasting only when the exact hover action is bound. Direction and vertical momentum are retained. Current hover position is used, with no teleport back to the LT press point. Native sprint displacement and code coasting are not applied at the same time.

**2档切悬停惯性时间常数（秒）** is independent of gear 1 response settings, default **0.8 seconds**, range **0–3**. Zero disables coasting. As an illustration, a measured 20 m/s velocity with a 0.8-second constant yields approximately 16 meters of total ideal coasting displacement. This is not a measurement of the game's sprint speed.

Short/stale samples, long frame gaps, implausible position jumps, ground contact, changed bindings, external actions and new sprint selection cannot reuse old momentum. Pause freezes bound coasting. Default reads occur only during sprint/transition; native parameter inspection remains off.

DEBUG → **原生冲刺速度只读检查** optionally reads the exact owned FlightControl at most four times per second and displays `OldFlySpeedXZ`, `FlightMoveVector`, `FlightAttitudeAddSpeed`, `FlightAttitudeAddSpeedStore` and `StatusParameter.get_FlySpeedRate()`. It writes no native fields and does not enable diagnostic logging. Local game metadata confirms these members; their causal effect on speed is not yet verified. Shared flight parameter assets are not modified. Dive/climb speed modulation is not enabled in this version.

Offline tests cover 3D speed estimation, analytic coasting and 30/120Hz agreement, transition resampling, pause, invalid samples, lifecycle, zero/save and bounded read-only inspection, plus previous gameplay regressions. In-game acceptance is still needed: end driving, Reset scripts, confirm v0.3.6, sprint steadily for about two seconds, note the measured speed and press LT. Check that it continues in the original direction and slows down. Then compare native readouts during level flight, dive and climb before choosing a speed-control entry point.
