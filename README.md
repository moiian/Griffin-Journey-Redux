# Griffin Journey Redux

Fly a friendly Griffin with configurable controls, a head-following camera, and separate seats for the player, pawns, and accompanying NPCs.

Version: **0.3.1**. Requires the installed NickCore EnemySpawner and `run_once` utility. This package does not include or modify NickCore.

## Install or upgrade

Copy `reframework/autorun` from the package into the game folder. When upgrading from the Beta, remove the old `reframework/autorun/GriffinFlightBeta.lua` entry before loading the new script. Keep `reframework/data/GriffinFlightBeta_Settings.json`: existing controls and seat presets are reused.

Open **Griffin Journey Redux → 一般设置**, spawn a Griffin, and start driving. End driving before resetting scripts. Only the Griffin spawned by this mod is controlled.

## Controls

| Action | Keyboard default | Controller default |
| --- | --- | --- |
| Start / stop driving | F / X | Rebindable |
| Take off (ground only) | Space | A |
| Gear 1 forward/back and turn | WASD | Left stick |
| Gear 1 code up / down | E / Q | A / Y |
| Gear 1 native landing | G | RS (right-stick press) |
| Sprint / gear 2 | Left Shift | RT |
| Hover / gear 1 | Left Ctrl | LT |
| Sprint dive / climb | C / R | RB / LB |
| Camera | Mouse | Right stick |
| Retarget the player | H | Rebindable |

There are two gears: gear 1 hover and gear 2 sprint. Ground-only takeoff finishes in gear 1. At low speed, forward/back moves along the Griffin's facing, left/right turns it, and A/Y moves vertically through code while using the same native hover action. There is no strafe. RS retains native landing. All movement/turn speeds accept zero. Player spherical navigation works in both gears.

RT selects gear 2. RB dive / LB climb also immediately select gear 2 from gear 1, then retain the existing sprint guidance. LT returns to gear 1 and preserves any existing low-speed inertia while suppressing held movement input until neutral. Releasing the stick or pressing LT in gear 1 does not reissue the hover action.

Flight Settings has independent horizontal acceleration, released-input deceleration and reverse-braking constants (defaults 0.2/0.6/0.6 seconds), plus independent vertical up-start/up-stop/down-start/down-stop constants (defaults 0.6/0.2/0.2/0.6 seconds). Each phase is separately adjustable; vertical reversal uses outgoing stopping and incoming startup response. All constants allow 0–3 seconds: larger values give more inertia, zero makes that stage immediate. Reversal brakes through zero before accelerating in the new direction. Settings save automatically. Former default bindings migrate once; custom bindings and explicit None remain.

The low-speed camera follows only while the Griffin is turning and stops correcting when rotation stops. Both gears share right-stick blending, takeover threshold, hysteresis and 0.8-second recovery delay, with separately adjustable follow speeds in Camera Settings. Camera pitch remains manually controlled. See [two-gear controls](CONTROLS_030_TWO_GEARS.md).

## Seats and camera

Edit the player, individual pawns, and accompanying NPCs independently. Presets support cloning, renaming, switching, and confirmed deletion. Seat positions, facing, body tilt, action names, camera distance, and FOV are saved automatically. Ordinary bystanders are not seated.

The camera can follow the Griffin's head. Its target is checked after submitted Griffin actions/retargeting and at most twice per second as a fallback, then rewritten only if the binding changed. Temporary native camera/controller transitions wait for safe recovery; turning the option off is respected. Optional gear 2 turning follows horizontally, with manual right-stick override. Pausing retains seat display; Photo Mode allows seat adjustments.

Steep, vertical and inverted body attitudes no longer automatically end driving or release seats. At exactly vertical attitudes, navigation retains the last valid horizontal heading.

Stopping driving restores the original camera and actor states at their current physical locations.

## Anti-jitter and diagnostics

Player and seated-NPC anti-jitter is enabled by default. Griffin anti-jitter is a separate option, disabled by default.

Diagnostic recording is **off by default**. User settings still save normally. The optional developer folder `_GriffinJourneyReduxDebug` adds a DEBUG panel with three fall experiments, protection controls, runtime diagnostics, and a three-second position recorder. Logs are written only when recording was explicitly enabled and the game is paused or driving has ended. Stopping a three-second recording while flying retains its data in memory until that save boundary.

The player package omits the developer folder. The developer package includes it, with unselected experiments and recording options disabled. Core driving, seats, camera, protection, and anti-jitter work without the developer folder.

## Validation and current limitation

Lua54 compilation and offline gameplay, scope, lifecycle, settings, default-no-diagnostics, and Debug-absent regressions pass. The user confirmed normal operation of the refactored 0.2.0 build. The action-time retargeting experiment has been reverted; the autonomous target issue remains unresolved.

AI target research is paused. This control update reduces ordinary movement action changes and does not claim to fix autonomous targets. The 0.2.8 camera guards pass offline checks; native movement stability and feel still require an in-game check.

Author: **aelinore**.


## Optional decision takeover (0.2.2)

Flight Settings includes **方向6：禁用狮鹫决策组件（实验）**, off by default and not saved. It disables only the current driven Griffin's AIDecisionMaker and restores its original Enabled value when disabled or driving ends. Native actions/navigation stay enabled. No recorder is required. See [AI_022_COMPONENT_TAKEOVER.md](AI_022_COMPONENT_TAKEOVER.md). It remains an optional experiment and is not an adopted AI fix. Leave it off for normal driving.


## Camera recovery (0.2.8)

Head-camera recovery no longer writes the target joint every behavior frame or permanently switches off on a temporary camera transition. Render camera diagnostics do no sampling when recording is disabled. The manual-camera post hook safely handles unavailable/nested hook storage and snapshots its state before native calls. Native camera clipping or shaking against terrain is a separate, unresolved visual issue; this update does not claim to change collision handling.
