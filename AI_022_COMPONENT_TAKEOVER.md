# Griffin Journey Redux 0.2.2: decision component takeover

Flight Settings adds **方向6：禁用狮鹫决策组件（实验）**. It is off by default, session-only, and works without developer files or recording. It can be armed before driving or toggled while driving.

This experiment adapts component-level takeover observed in Immersive Interactables' ox-driving implementation. It disables only the retained Griffin's AIDecisionMaker component. Existing SkipThink requests and native flight actions remain. NavigationAI, MonsterNavigationController, MotionFsm2, ActionManager and FlightControl are not disabled. No direct clip playback, Griffin position/rotation writes or action-time player retargeting is added.

The component's original Enabled value is captured and checked. Updates reapply false only if the same component becomes enabled again. Turning the option off, stopping driving and Reset restore the saved value, including original false. Paused gameplay does not perform ordinary component writes; explicit exit still restores. Changed/invalid instances are not written through stale pointers. Partial failures retain recovery state; failed restoration blocks a new driving session/deletion and can be retried.

The local native dump confirms AIDecisionMaker derives from via.Behavior and provides inherited Enabled accessors. Runtime checks validate getter/setter signatures and exact component ownership. An unavailable interface or failed takeover is reported and the experiment stops; a false readback alone does not establish correct native AI behavior.

After reloading to 0.2.2, enable the option and use normal movement, hover and movement again. Check the component status and whether the next action still first turns/moves toward an autonomous target. No recorder is required. If native flight stops responding, turn the option off to restore the captured value.

All 21 Lua54 files compile. Full gameplay, anti-jitter, developer/player packages and default no-diagnostic-output checks pass. Added checks cover positive/negative ownership, original true/false, changed-only enforcement, prearm/pause/off/exit/Reset, changed references, signature/readback failures, partial mutation rollback, saved recovery retry and actual UI/flight integration. Native flight compatibility and AI effectiveness remain unverified.
