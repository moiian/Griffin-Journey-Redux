# Griffin Journey Redux

Fly a friendly Griffin with configurable controls, a head-following camera, and separate seats for the player, pawns, and accompanying NPCs.

Version: **0.2.7**. Requires the installed NickCore EnemySpawner and `run_once` utility. This package does not include or modify NickCore.

## Install or upgrade

Copy `reframework/autorun` from the package into the game folder. When upgrading from the Beta, remove the old `reframework/autorun/GriffinFlightBeta.lua` entry before loading the new script. Keep `reframework/data/GriffinFlightBeta_Settings.json`: existing controls and seat presets are reused.

Open **Griffin Journey Redux → 一般设置**, spawn a Griffin, and start driving. End driving before resetting scripts. Only the Griffin spawned by this mod is controlled.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Start / stop driving | F / X | Rebindable |
| Take off from the ground | Space | A |
| Sprint / gear 2 | Left Shift | RT |
| Stop / gear 0 hover | Left Ctrl | LT |
| Slow movement / sprint steering | WASD | Left stick |
| Low-speed facing (no strafe) | A / D | Left stick horizontal |
| Camera | Mouse | Right stick |
| Climb / sprint descend; low-speed landing | E / Q | RB / LB |
| Retarget the player | H | Rebindable |

Gear 0 holds position. At low speed, left-stick forward/back moves along the Griffin's facing, and left/right turns it with a slight delay. There is no lateral movement. Forward, backward, vertical-climb and turning speeds are independent and can all be set to zero in Flight Settings. Hold RB (E) to climb vertically; LB (Q) retains landing.

The low-speed camera follows only while the Griffin is turning; it stops correcting when body rotation stops, even if some camera lag remains. Both gears share the same right-stick blending, takeover threshold, hysteresis and 0.8-second recovery delay. Adjust **1档镜头跟随速度（度／秒）** and **2档镜头跟随速度（度／秒）** independently in Camera Settings. Low-speed speed zero disables its automatic yaw. Camera pitch remains manually controlled.

RT goes directly to gear 2, preserving the previous sprint guidance and separate sprint-camera settings. LT brakes directly to stationary hover; if movement/climb input is held, release it before moving again. Controls can be changed in the menu.

## Seats and camera

Edit the player, individual pawns, and accompanying NPCs independently. Presets support cloning, renaming, switching, and confirmed deletion. Seat positions, facing, body tilt, action names, camera distance, and FOV are saved automatically. Ordinary bystanders are not seated.

The camera can follow the Griffin's head. Optional gear 2 turning follows horizontally, with manual right-stick override. Pausing retains seat display; Photo Mode allows seat adjustments.

Steep, vertical and inverted body attitudes no longer automatically end driving or release seats. At exactly vertical attitudes, navigation retains the last valid horizontal heading.

Stopping driving restores the original camera and actor states at their current physical locations.

## Anti-jitter and diagnostics

Player and seated-NPC anti-jitter is enabled by default. Griffin anti-jitter is a separate option, disabled by default.

Diagnostic recording is **off by default**. User settings still save normally. The optional developer folder `_GriffinJourneyReduxDebug` adds a DEBUG panel with three fall experiments, protection controls, runtime diagnostics, and a three-second position recorder. Logs are written only when recording was explicitly enabled and the game is paused or driving has ended. Stopping a three-second recording while flying retains its data in memory until that save boundary.

The player package omits the developer folder. The developer package includes it, with unselected experiments and recording options disabled. Core driving, seats, camera, protection, and anti-jitter work without the developer folder.

## Validation and current limitation

Lua54 compilation and offline gameplay, scope, lifecycle, settings, default-no-diagnostics, and Debug-absent regressions pass. The user confirmed normal operation of the refactored 0.2.0 build. The action-time retargeting experiment has been reverted; the autonomous target issue remains unresolved.

AI target research is paused. This control update reduces ordinary movement action changes and does not claim to fix autonomous targets. The 0.2.7 control scheme passes offline checks; native movement stability and feel still require an in-game check.

Author: **aelinore**.


## Optional decision takeover (0.2.2)

Flight Settings includes **方向6：禁用狮鹫决策组件（实验）**, off by default and not saved. It disables only the current driven Griffin's AIDecisionMaker and restores its original Enabled value when disabled or driving ends. Native actions/navigation stay enabled. No recorder is required. See [AI_022_COMPONENT_TAKEOVER.md](AI_022_COMPONENT_TAKEOVER.md). It remains an optional experiment and is not an adopted AI fix. Leave it off for normal driving.
