# Two-gear controls — 0.3.0

Gear 1 is hover, including all code-driven slow movement. Gear 2 is native sprint. Takeoff remains ground-only and finishes in gear 1; there is no gear 0.

| Action | Controller default | Keyboard default |
| --- | --- | --- |
| Take off (ground only) | A | Space |
| Gear 1 forward/backward and turn | Left stick | WASD |
| Gear 1 vertical up | A | E |
| Gear 1 vertical down | Y | Q |
| Gear 1 native landing | RS (right-stick press) | G |
| Sprint / gear 2 | RT | Left Shift |
| Hover / gear 1 | LT | Left Ctrl |
| Sprint dive (enters gear 2 from gear 1) | RB | C |
| Sprint climb (enters gear 2 from gear 1) | LB | R |
| Manual camera | Right stick | Mouse |

In gear 1, translation and rotation use the same native hover action throughout. Releasing movement or pressing LT does not reissue that action. LT clears the requested movement while preserving current horizontal, vertical and turning inertia. Held movement input must return to neutral before it can start moving again. Switching from gear 2 to gear 1 still submits the native hover action once.

A/Y move vertically through code while hovering. They do not request takeoff or landing in the air. Holding both requests zero vertical speed and eases the current motion down. RS retains the native landing action and releases code movement. RB/LB immediately select gear 2 and submit the sprint action once; holding/changing shoulders continues native sprint guidance without repeated action requests.

Flight Settings exposes separate up/down speeds (both accept zero) and independent **1档上移惯性时间常数（秒）** / **1档下移惯性时间常数（秒）**. Each time constant controls acceleration and release for that vertical direction, default 0.6 seconds, range 0–3. Vertical reversal brakes with the outgoing direction's constant before accelerating with the incoming constant. Horizontal movement retains the three acceleration/deceleration/reverse-braking settings. Zero means immediate response; larger values mean more inertia.

Player spherical navigation now responds in gear 1 as it does in gear 2. Right-stick camera control and shared turning-camera policy are retained.

On upgrade, former default shoulder/keyboard bindings migrate once to the new defaults. Custom bindings and explicit None remain. New actions get their defaults; seat, speed, camera and other personal settings remain. Settings save automatically during normal script operation.

End driving before Reset scripts and confirm v0.3.0. Check takeoff, code up/down and release, LT during movement, RS landing, RB/LB gear transition and low-speed player navigation. Offline tests cover these transitions, analytic inertia and 30/120Hz consistency; native handling and visuals still need in-game acceptance.
