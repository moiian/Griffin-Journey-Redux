# Sprint speed experiments shelved — failure archive 0.3.11

Status: shelved at the user's request. The current native sprint speed-control and additive sprint-motion routes did not achieve the intended effect. Do not resume these experiments automatically. Retain the independent LT measured-velocity handoff and hover coasting.

Archive branch: `archive/failed-sprint-speed-0.3.11`. It preserves the experimental source and developer tools. It is a failed experiment backup, not a verified release. The maintained branch returns to clean 0.3.12 with these tools removed.

| Experiment | Observed outcome | Scope of conclusion |
| --- | --- | --- |
| Scoped FlySpeedRate getter multiplier | No observed native getter hits or intended speed reduction | The tested getter path was not validated; caching/inlining remains unproven |
| FlightMoveVector pre-updatePosition scaling | Controller callbacks and write calls occurred; no intended speed reduction | The tested insertion point failed; early write counts did not immediately verify the written value |
| Read-only native timing | Movement was visible between observed callbacks, not within their position snapshots | Did not locate the final authoritative movement writer |
| Post-UpdateBehavior fixed +6 m/s overlay | Immediate Transform/controller readbacks matched; no measured or visible acceleration | Same-call consistency did not establish persistent extra displacement |
| Post-LateUpdateBehavior same overlay | No measured or visible acceleration; subsequent checkpoints showed no opposite-direction motion | This phase switch also failed; absence of backward motion does not rule out ignored/canceled displacement |

The tested overlays added incremental displacement to the current position, synchronized Transform/PosRotContext/controller warp, preserved rotation/native sprint/navigation, and stopped without restoring an old position. They did not establish effective native sprint speed control. Offline positive simulations tested our arithmetic and cleanup only; they did not validate game behavior.

A separate native movement accumulator or cached origin may dominate subsequent sprint updates, but neither that mechanism nor a specific overriding component has been proven. Do not state that all code displacement is impossible, that a multiplier only applies on the next action, or that a reverse-motion counter of zero proves persistence. Do not widen AI/component freezes to pursue this abandoned feature.

A future restart requires explicit user direction and new evidence identifying the movement source or consumer, not repeated blind field/phase changes. Dive accumulation, level-flight speed decay and climb slowdown remain unimplemented. The retained LT handoff samples actual sprint world velocity and applies coasting only after hover binds; it is a separate feature.

Clean 0.3.12 removes the three optional experimental modules, their lifecycle/frame/render callbacks, native member inspection, menu toggles and experiment-only reads/writes. Normal sprint sampling remains because LT inertia needs it. Earlier experiment instructions are preserved on the archive branch, not shipped as active instructions.
