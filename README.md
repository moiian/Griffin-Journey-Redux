# Griffin Journey Redux

Version **0.3.44** · Author **aelinore**

Fly a friendly Griffin with configurable controls, a head-following camera, and individual seats for the player, pawns, and accompanying NPCs. Requires the installed **NickCore**, its EnemySpawner, and `run_once`. Only the exact Griffin created by this mod is controlled.

## Install or upgrade

The **Runtime** archive contains the player scripts. Extract its `reframework` folder into the game directory. Keep `reframework/data/GriffinFlightBeta_Settings.json` and your existing item bundle and textures. This runtime update does not contain or replace personal configuration, item data, third-party mods, or developer tools.

For an existing Beta installation, remove the old `GriffinFlightBeta.lua` entry before loading Griffin Journey Redux. End driving before resetting scripts. The public player installation does not need `_GriffinJourneyReduxDebug`.

The separately supplied **Debug Addon** installs `_GriffinJourneyReduxDebug` alongside the player modules. It connects to the existing driver and does not run another copy of the mod. Remove this folder for a player-only installation. Experiments and recording start off, even if older settings enabled them.

## Configure and save

Open **Griffin Journey Redux** in REFramework. The controls at the top apply to seat presets, flight, camera, summoning, collision settings, and key bindings:

- **实时应用修改**: off at script startup. With it off, edits stay in a draft and the current configuration remains active. With it on, edits preview in memory without saving to disk.
- **应用并保存**: applies the draft and writes the settings file once. Repeated slider changes never write the file. A failed save keeps the draft and displays an error for retry.
- **恢复未修改**: restores the last saved configuration and cancels a queued save. Script resets discard unsaved drafts and previews.
- **恢复默认配置**: rebuilds the complete default draft, including camera, flight, summoning, bindings and default seat layouts. Preview is turned off and previous queued edits are canceled. Use **应用并保存** to apply and persist it, or **恢复未修改** to return to your saved configuration. Optional developer switches return to startup defaults when this draft is applied; normal pause defers native changes.

Choose **编辑布局（应用后生效）** to edit a layout. Normal presets start at [2]. Clone, rename, and delete layouts in the draft, then apply them. Player and passenger seats have independent position, facing, tilt, and action settings. Ordinary bystanders are not seated. Physical calibration layout [1] is available through the Debug Addon only.

Ordinary paused menus defer application until gameplay resumes. Photo Mode allows visual seat preview while physics, flight controls, and new animation requests remain paused. Preset hotkeys remain immediate gameplay actions; their selection is saved only when **应用并保存** is pressed. Key recording edits the draft; game controls continue using applied bindings.

## Driving

Use **一般设置** to spawn a Griffin or play the summoning performance, then start driving. Start/stop hotkeys require a continuous one-second hold. Starting checks the configured three-dimensional distance between the player and this mod's Griffin. Existing bindings and calibrated settings are reused.

- Gear 1: custom slow movement and hover, turning, and independent vertical movement with inertia.
- Gear 2: native sprint and player-target navigation. LT returns to hover and coasts using sampled sprint velocity. Native hover can also adopt gear 1 automatically.
- A starts takeoff on the ground. Takeoff has a 1.89-second minimum before normal hover/sprint handoff. RS requests native landing in either gear.

The body guard applies only to gear 1. It uses fixed directional probe lengths, rejects blocked writes, and waits for held input to change before retrying. Near-ground landing covers both gears, with the existing 5 Hz / 20 Hz limits and three-hit confirmation. Camera distance and FOV are global and do not change with seat presets.

Player and seated-NPC anti-jitter and scoped protection remain gameplay features. Voluntary exit captures the current layout's seat positions before releasing actors. An airborne Griffin lands when a surface is within 25 metres below its root and hovers otherwise. Automatic protection and deletion retain their separate recovery behavior.

## Items and developer tools

Existing chocolate summoning, pizza grant/use, native shop stock, and cleanup integrations are retained. This update leaves installed item bundles and custom icons untouched. A fresh item installation still needs the existing Content Editor bundle and assets, which are not included in this runtime-only update.

The Debug Addon contains the optional decision-component experiment, Griffin anti-jitter, return-to-safe collision comparison, full-display mode, extra loss/destroy guards, physical-layout display, item test buttons, input diagnostics, collision recording, and position/fall probes. It reuses the release's driver, seat pipeline, inventory operations, and fall-control engine. Logging requires explicit recording; ordinary pizza use no longer writes a grant log.

Lua54 compilation, offline behavior checks, and both player-only and add-on installation modes were checked. These checks do not establish a measured FPS improvement or new in-game visual acceptance. Previously shelved AI target and sprint-speed experiments remain shelved.

## Hide HUD

Open **详细配置 → 隐藏界面**. The master switch, four timing conditions and eight HUD categories are independent and enabled by default. Conditions: 20 gameplay seconds after an accepted summon, driving, 10 gameplay seconds after leaving the driver, or while the exact exited Griffin is still in its native hovering action. Menu/hotkey/direct spawn and performance/item API paths share these events. Pauses do not consume the timers; pending/rejected or canceled summons do not restart or retain a false hiding window.

Categories: player skills, pawn commands, player HP, player stamina, player status icons, boss HP, pawn names/HP, and minimap. Other HUD and menus pass through. Whole selected groups are skipped at GUI drawing; selective player panels are restored after the draw, with end-of-render/reset recovery. The feature does not require HUD Controls or Hotkeys and does not alter their files. HUD switches follow draft/preview/explicit-save/default-reset behavior. Visual behavior and coexistence with another active HUD mod require in-game confirmation.
