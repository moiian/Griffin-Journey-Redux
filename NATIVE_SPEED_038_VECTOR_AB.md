# Native instance-vector A/B test — 0.3.8

This optional Debug experiment tests whether `FlightControl.FlightMoveVector` controls native sprint displacement. The previous speed-rate getter experiment did not establish native speed control; that getter is now diagnostic only. Dive/climb speed modulation is not enabled.

End driving and Reset scripts; confirm v0.3.8. Sprint steadily for about two seconds, then press **原生位移向量对照（0.8倍，自动恢复）** in DEBUG. Maintain level flight without turning or shoulder inputs for about six seconds. Record the three speed lines, current/all-controller call counts, vector components and any interface/context error.

The sequence samples A for 1.5 seconds, scales the exact driven controller's instance vector by 0.8 during `updatePosition()` for 2.5 seconds, then samples recovery for 1.5 seconds. Settling samples are excluded. No shared status fields, persistent settings or logs are written. Hooks install on demand; inactive callbacks perform no native reads.

Each native call captures the vector before scaling and restores it afterward only if it still equals the test value. Engine-written replacements are preserved. Cancellation restores outstanding changes; failed restoration remains queued across script reset and blocks another test or normal lifecycle completion until resolved. Other Griffin controllers are excluded, including those sharing the status object.

A successful result requires measured horizontal speed near 0.8 of baseline, recovery near baseline, stable baseline and actual vector writes. Writes or hook counts alone do not establish speed control. Update/late/position/getter counts distinguish an uncalled method from an observed but ineffective vector path; missing hook context and interface errors are reported separately.

All 24 Lua54 files compile and existing controls, camera, inertia, takeoff, seating and lifecycle regressions pass. New mock tests cover lazy installation, exact-controller exclusion, unchanged getter, nested updates, engine overwrite preservation, nil/reset/stop cleanup, failed restoration retry, positive A/B/recovery and rejection of writes with no measured speed response. Native effect remains unverified until in-game testing.
