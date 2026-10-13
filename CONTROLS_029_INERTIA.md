# Gear 1 inertia — 0.2.9

Flight Settings now exposes three independent time constants (0–3 seconds):

| Setting | Default | Applies to |
| --- | --- | --- |
| 1档加速时间常数（秒） | 0.2 | Forward/backward and vertical-climb acceleration |
| 1档松杆减速时间常数（秒） | 0.6 | Released/reduced movement input and released climb |
| 1档反向刹车时间常数（秒） | 0.6 | Braking an existing velocity against opposing input |

Larger values produce slower responses and longer drift. Zero makes that stage immediate. A time constant is not the total stopping time: after one time constant, about 37% of the original velocity difference remains.

Opposing input brakes through zero, then uses the acceleration setting to build velocity in the new direction. There is no input lock or mandatory pause. LT retains its immediate stop and release-before-moving gate. Body turning and gear 2 controls/camera behavior are unchanged.

Settings save automatically. Existing speed, control, camera and seat settings are retained. The new defaults apply when a field is missing.

End driving and reset scripts before testing; confirm v0.2.9. Try forward/release, forward/reverse, and climb/release, changing one constant at a time. Offline regression covers settings, zero values, horizontal/vertical response, reversal, LT and frame-rate consistency. In-game feel remains to be checked.
