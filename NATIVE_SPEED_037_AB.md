# Native speed-rate A/B test — 0.3.7

This developer-only test verifies whether `FlightControlStatusParameter.get_FlySpeedRate()` affects native sprint displacement. It does not enable dive/climb speed modulation.

End driving and Reset scripts; confirm v0.3.7. Sprint steadily for about two seconds, then open DEBUG and press **原生速度倍率对照（0.8倍，自动恢复）**. Diagnostic recording need not be enabled. Keep flying straight and approximately level for about six seconds without RB/LB. Results remain visible as three short lines: original A, temporary 0.8 B, and restored speed. Compare the horizontal speeds.

The test collects original speed for 1.5 seconds, applies the candidate 0.8 return-value multiplier for 2.5 seconds, then collects restored speed for 1.5 seconds. Settling intervals are excluded from the averages. Significant turning/ascent/descent, stale measurements, pause, gear changes, ownership/controller replacement, manual stop and script exit cancel the test and restore native output. Mild vertical movement is tolerated; measured horizontal speed is used for comparison.

Hooks install only when starting the test. Scoped return changes apply only inside the driven Griffin's exact FlightControl update/lateUpdate, on the current status parameter and native thread. Shared parameter objects are never written. Other controllers, unscoped reads and retired scripts return the original value. Inactive installed callbacks pass through without parameter reads. Hook-call storage is ephemeral, so cross-hook scopes are separately keyed by native thread ID; see the [REFramework thread API](https://cursey.github.io/reframework-book/api/thread.html).

A successful result requires actual speed reduction near 0.8 of the original, subsequent recovery near the original, stable baseline and observed getter hits. A getter hit alone does not prove speed control. “未命中速度读取入口” or “未证实按倍率调速” means the candidate remains unverified.

Offline tests cover separate per-call storage, exact instance/thread/shared-parameter negative cases, nesting, nil context, cancellation, automatic restoration, positive speed response and rejection when no speed change occurs. Native confirmation is still required before a unified dive/climb speed model is enabled.
