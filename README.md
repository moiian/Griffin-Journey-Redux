# Griffin Journey Redux

Fly a friendly Griffin with configurable controls, a head-following camera, and separate seats for the player, pawns, and accompanying NPCs.

Version: **0.3.16**. Requires the installed NickCore EnemySpawner and `run_once` utility. This package does not include or modify NickCore.

## Install or upgrade

Copy `reframework/autorun` from the package into the game folder. When upgrading from the Beta, remove the old `reframework/autorun/GriffinFlightBeta.lua` entry before loading the new script. Keep `reframework/data/GriffinFlightBeta_Settings.json`: existing controls and seat presets are reused.

Open **Griffin Journey Redux → 一般设置**, spawn a Griffin, and start driving. End driving before resetting scripts. Only the Griffin spawned by this mod is controlled.

The manual **召唤演出测试** button plays the native forgery-Ferrystone performance and requests a Griffin spawn after a configurable delay (default: 5 seconds of unpaused gameplay; range: 0–30 seconds). **召唤演出设置** also controls the height and forward distance (defaults: 10 m above the player's position and 5 m forward). Settings are captured when the button is pressed. If the performance finishes normally before the selected delay, the summon waits until that delay. The Griffin faces the player horizontally once its returned instance is ready, and uses the same friendly and SkipThink initialization as the ordinary spawn button. Driving remains manual. The native performance can consume a forgery Ferrystone if one is carried.

When the controlled Griffin naturally enters the stationary hover action in flight, gear 1 controls activate without pressing LT. LT still requests hover manually and retains its existing inertia and input-centering behavior.

An optional **飞行设置 → 1档防穿模测试** experiment checks gear 1 requests before submitting movement. Enable **启用1档防穿模（实验）** to try it; it defaults off after a script reload. Planning happens before behavior update; a single post-behavior pass sweeps three body volumes in both directions. Any environment contact rejects the whole step, clears movement inertia and skips every pose setter and warp. The last accepted pose remains the reference; native position drift over 5 cm pauses code movement instead of snapping back. Radius, center height, front/rear spacing and margin are adjustable for the session. Gear 2 performs no queries or interception. Existing overlap may block escape or tangential movement. Coverage, stability and body sizing require in-game testing; see [0.3.16 preflight experiment](COLLISION_0316_PREFLIGHT.md).

## Controls

| Action | Keyboard default | Controller default |
| --- | --- | --- |
| Start / stop driving | F / X | Rebindable |
| Take off (ground only) | Space | A |
| Gear 1 forward/back and turn | WASD | Left stick |
| Gear 1 code up / down | E / Q | A / Y |
| Native landing (gear 1 or 2) | G | RS (right-stick press) |
| Sprint / gear 2 | Left Shift | RT |
| Hover / gear 1 | Left Ctrl | LT |
| Sprint dive / climb | C / R | RB / LB |
| Camera | Mouse | Right stick |
| Retarget the player | H | Rebindable |

There are two gears: gear 1 hover and gear 2 sprint. Ground-only takeoff waits at least 1.89 seconds of unpaused time after observed action start before automatic hover or sprint. Early RT/RB/LB selection is queued; held movement/A/Y flows into code control after the wait without release or LT. At low speed, forward/back moves along the Griffin's facing, left/right turns it, and A/Y moves vertically through code while using the same native hover action. There is no strafe. RS retains native landing in either gear. All movement/turn speeds accept zero. In gear 1 the player's real position follows preset [1] player parameters; entering gear 2 via RT/RB/LB immediately restores spherical navigation. Returning with LT restores preset [1] anchoring. Current visual seats remain independent.

RT selects gear 2. RB dive / LB climb also immediately select gear 2 from gear 1, then retain the existing sprint guidance. LT returns to gear 1 and preserves any existing low-speed inertia while suppressing held movement input until neutral. Releasing the stick or pressing LT in gear 1 does not reissue the hover action.

Flight Settings has independent horizontal acceleration, released-input deceleration and reverse-braking constants (defaults 0.2/0.6/0.6 seconds), plus independent vertical up-start/up-stop/down-start/down-stop constants (defaults 0.6/0.2/0.2/0.6 seconds). Each phase is separately adjustable; vertical reversal uses outgoing stopping and incoming startup response. All constants allow 0–3 seconds: larger values give more inertia, zero makes that stage immediate. Reversal brakes through zero before accelerating in the new direction. Settings save automatically. Former default bindings migrate once; custom bindings and explicit None remain.

Sprint-to-hover LT now inherits measured world velocity and coasts after native hover binds. Flight Settings displays sprint speed and provides **2档切悬停惯性时间常数（秒）** (default 0.8, range 0–3; zero disables coasting). Invalid or stale samples do not produce momentum. Dive/climb speed modulation is shelved; the failed experiments and native parameter inspection have been removed. See [sprint momentum](SPRINT_036_LT_MOMENTUM.md).

The low-speed camera follows only while the Griffin is turning and stops correcting when rotation stops. Both gears share right-stick blending, takeover threshold, hysteresis and 0.8-second recovery delay, with separately adjustable follow speeds in Camera Settings. Camera pitch remains manually controlled. See [two-gear controls](CONTROLS_030_TWO_GEARS.md).

Ordinary airborne actions, including hover, are not submitted on the ground. DEBUG includes **禁止跨阶段动作**, checked by default, to disable this guard for the current script session when testing. Reload restores the guard; external action tools retain their own explicit cross-phase option. See [phase guard and landing](PHASE_032_LANDING.md).

Sprint speed experiments are shelved. The clean version removes native speed inspection, multiplier/vector tests, timing probes and code-overlay controls/callbacks. Native sprint remains unchanged; measured-velocity LT coasting stays available. The failed experiment source is preserved on `archive/failed-sprint-speed-0.3.11`. See [failure handoff](SPRINT_SPEED_EXPERIMENTS_SHELVED.md).

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
