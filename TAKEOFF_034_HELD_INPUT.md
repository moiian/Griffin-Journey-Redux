# Early hover handoff and held input — 0.3.4

Once native flight is active and ground contact is clear, automatic takeoff requests gear 1 hover without waiting for the takeoff action to finish. The existing action request cooldown still applies; code motion starts when hover is active.

Remove the release-before-moving gate from automatic takeoff. Forward/back, turning and A/Y held before control becomes available flow into code movement without a fresh press. Holding A through takeoff continues upward in gear 1. LT retains its separate intentional neutral-input gate and inertia behavior.

Ground phase restrictions, both-gear RS landing, sprint controls and independent vertical inertia remain. Offline regression covers early airborne handoff while takeoff is still active, held forward/back/up/down, pause/resume and preserved LT behavior. Native timing and feel remain for in-game acceptance.

End driving and Reset scripts; confirm v0.3.4. Test by holding forward, A or Y across takeoff without releasing or pressing LT.
