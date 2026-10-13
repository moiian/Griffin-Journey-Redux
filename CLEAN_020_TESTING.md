# Griffin Journey Redux 0.2.0 validation

Lua54 compilation and the existing complete gameplay regression pass after the module split. Tests cover flight gears, input rebinding, head camera/yaw, presets, independent physical/Hip seats, pawns and accompanying NPCs, pause/Photo Mode, recovery and reset.

Scoped native free-fall stop/start interception passes positive and unrelated-instance cases, controller replacement, per-NPC failure isolation, release/re-entry and coexistence with all three retained fall experiments. The actual clean-module integration also passes these cases through the new user-facing switches.

Developer and player packages were tested separately; the latter physically contains no Debug folder. Default sustained driving, pause, exit and reset produce no diagnostic output or health telemetry reads; settings still save. Enabled diagnostics retain at most 600 samples and 400 events, save changed data once while paused, and retry failed output. The three-second recorder never writes at its flying-time deadline and retains failed output until retry.

No in-game visual acceptance of the refactored 0.2.0 build is claimed. Check the new menu, normal flight and seats, pause/Photo Mode, and stopping driving during ordinary use. The user's unresolved Griffin decision-target issue is recorded without analysis in GRIFFIN_JOURNEY_REDUX_HANDOFF.md.
