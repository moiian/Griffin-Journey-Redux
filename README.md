# Griffin Journey Redux

Fly a friendly Griffin with configurable controls, a head-following camera, and separate seats for the player, pawns, and accompanying NPCs.

Version: **0.2.0**. Requires the installed NickCore EnemySpawner and `run_once` utility. This package does not include or modify NickCore.

## Install or upgrade

Copy `reframework/autorun` from the package into the game folder. When upgrading from the Beta, remove the old `reframework/autorun/GriffinFlightBeta.lua` entry before loading the new script. Keep `reframework/data/GriffinFlightBeta_Settings.json`: existing controls and seat presets are reused.

Open **Griffin Journey Redux → 一般设置**, spawn a Griffin, and start driving. End driving before resetting scripts. Only the Griffin spawned by this mod is controlled.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Start / stop driving | F / X | Rebindable |
| Take off from the ground | Space | A |
| Sprint / gear 3 | Left Shift | RT |
| Decrease gear | Left Ctrl | LT |
| Steer | WASD | Left stick |
| Gear-dependent climb / descend / hover / land | E / Q | RB / LB |
| Retarget the player | H | Rebindable |

Gear 1 provides small movements and hover when centered. Gear 2 provides directional hover movement. Gear 3 uses fast target-directed flight. Controls can be changed in the menu.

## Seats and camera

Edit the player, individual pawns, and accompanying NPCs independently. Presets support cloning, renaming, switching, and confirmed deletion. Seat positions, facing, body tilt, action names, camera distance, and FOV are saved automatically. Ordinary bystanders are not seated.

The camera can follow the Griffin's head. Optional gear 3 turning follows horizontally, with manual right-stick override. Pausing retains seat display; Photo Mode allows seat adjustments.

Stopping driving restores the original camera and actor states at their current physical locations.

## Anti-jitter and diagnostics

Player and seated-NPC anti-jitter is enabled by default. Griffin anti-jitter is a separate option, disabled by default.

Diagnostic recording is **off by default**. User settings still save normally. The optional developer folder `_GriffinJourneyReduxDebug` adds a DEBUG panel with three fall experiments, protection controls, runtime diagnostics, and a three-second position recorder. Logs are written only when recording was explicitly enabled and the game is paused or driving has ended. Stopping a three-second recording while flying retains its data in memory until that save boundary.

The player package omits the developer folder. The developer package includes it, with unselected experiments and recording options disabled. Core driving, seats, camera, protection, and anti-jitter work without the developer folder.

## Validation and current limitation

Lua54 compilation and offline gameplay, scope, lifecycle, settings, default-no-diagnostics, and Debug-absent regressions pass. The user confirmed normal operation of the refactored 0.2.0 build. The action-time retargeting experiment has been reverted; the autonomous target issue remains unresolved.

The user still observes autonomous Griffin decision targets being used when a new action is requested, despite think skipping. This remains unresolved.

Author: **aelinore**.
