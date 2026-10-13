# Landing from both gears and ordinary action phases — 0.3.2

RS (G) now requests native landing from either gear 1 or gear 2, selects gear 1 and releases code movement. Holding RS does not repeat the landing request.

Ordinary hover/sprint/landing requests require flight without ground contact. Takeoff requires ground contact without flight. Grounded hover requests are canceled, preserving the native grounded action. Returning airborne rearms one hover request when gear 1 control is active. Native submission rechecks the phase so queued commands cannot bypass the guard.

DEBUG → **禁止跨阶段动作** is checked by default, even with diagnostic recording off. Unchecking allows ordinary cross-phase action testing, including ground hover or airborne takeoff. It is session-only, not saved to player settings, and resets to checked after script reload. Player packages without Debug retain the default guard. External action tools keep their existing explicit `allow_cross` contract.

All 22 Lua54 modules and existing/new offline regressions pass, covering both-gear landing, held-input deduplication, grounded hover cancellation, airborne recovery, default/on/off/reset behavior and queued phase transitions. Native behavior remains to be checked in game. Gear 2 inertia is not changed in this version.
