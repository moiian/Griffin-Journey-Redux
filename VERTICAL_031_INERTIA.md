# Separate vertical startup and stopping — 0.3.1

Gear 1 now has four independent time constants in Flight Settings:

| Setting | Default |
| --- | --- |
| 1档上移启动时间常数（秒） | 0.6 s |
| 1档上移停止时间常数（秒） | 0.2 s |
| 1档下移启动时间常数（秒） | 0.2 s |
| 1档下移停止时间常数（秒） | 0.6 s |

Each allows 0–3 seconds and saves automatically. Larger values slow that phase; zero makes it immediate. These simulate slower ascent startup, faster ascent stopping, faster descent startup and slower descent stopping through code-controlled movement.

Released input, simultaneous up/down input and LT use the current direction's stopping constant. Reversing vertical direction first brakes through zero with the outgoing stopping constant, then accelerates with the incoming startup constant. Input remains responsive throughout.

The former up constant migrates to up startup; the former down constant migrates to down stopping. New explicit fields, including zero, take precedence. The two new faster phases default to 0.2 seconds. Controls, horizontal inertia, speeds and camera settings retain their behavior.

End driving and Reset scripts, then confirm v0.3.1. Offline checks cover defaults, migration, save/reload, independent phase response, zero/bounds, reversal, LT and prior two-gear regressions. Actual game feel still requires acceptance.
