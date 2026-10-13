# Low-speed controls — 0.2.5

Left-stick lateral movement is reversed relative to 0.2.4 following in-game feedback. The same corrected right-positive low-speed axis now drives body yaw. Keyboard A/D retains conventional left/right movement independently of the existing sprint mapping. The former right-stick body-yaw input and low-speed camera-yaw suppression are removed; right-stick camera input remains native.

Flight Settings now provides separate forward, strafe, backward, vertical climb and turning speeds. Every slider and saved value accepts zero. Defaults are 3 / 1.5 / 1.5 / 1.5 m/s and 75 degrees/s. An old shared `hover_speed` initializes forward speed and half-speed strafe/backward defaults; explicit new values, including zero, take precedence. Existing turn speed remains compatible. Settings are saved normally, independently of diagnostics.

Hold RB (E) in low-speed hover for code-driven world-vertical ascent; releasing eases to zero upward velocity. It works with horizontal movement and does not issue the former RB hover/brake action. LB landing and gear 2 sprint shoulder guidance are unchanged. LT brakes horizontal/vertical/turn velocity and gates held movement/climb input until release. Right-stick camera input does not participate in this gate.

All 22 Lua54 files compile. Existing gameplay, exact-instance anti-jitter, seats, camera, steep attitudes, default-no-diagnostics and Debug-absent package regressions pass. New checks cover zero-speed UI/save/reload, shared-speed migration, independent directional speeds, corrected pad/keyboard translation and yaw, native right-stick camera, held vertical ascent without native action requests, release damping, combined movement, LT vertical braking and unchanged LB landing. Direction expectations incorporate user feedback; native in-game direction and feel still require confirmation.

End driving, Reset scripts, and verify v0.2.5. For isolated checks, set turn speed to zero to test strafing, or strafe speed to zero to test left-stick yaw. Test RB ascent from hover and confirm right-stick camera movement.
