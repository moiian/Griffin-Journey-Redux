# Takeoff-to-hover control handoff — 0.3.3

Fix a takeoff transition where the native animation reaches hover before Flight/Ground flags settle. The old grounded-tail branch disabled controls and exited the takeoff handoff, leaving later airborne hover without code movement until LT was pressed.

Automatic takeoff now waits through late or overlapping flags, then explicitly enables gear 1 controls once flight is active and ground contact is clear. An already-active exact hover action is adopted without resubmission. Other airborne nodes receive one hover request. Held movement/climb input still needs release before starting, without requiring LT.

Manual gear/landing selections and external takeover still cancel automatic handoff. Ground action guards, inertia and camera behavior are retained. The actual 0.3.2 flight module reproduces the disabled-control failure offline; 0.3.3 passes the same case and all existing regressions. Native behavior remains to be checked in game.

End driving, Reset scripts and confirm v0.3.3. Take off, release A/stick, then try forward/back and A/Y without pressing LT.
