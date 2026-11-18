# Roblox Studio setup (manual, without Rojo)

With Rojo you can skip this page: `default.project.json` produces exactly this layout.

## 1. Create the place
1. Roblox Studio → **New → Baseplate**.
2. *(For saving)* **File → Publish to Roblox**, then **Home → Game Settings → Security → Enable Studio Access to API Services**.
3. **Home → Game Settings → Basic Info / Places → Max Players = 8.** The Ninja Village has 8 plots, one per player.
4. Leave the default Baseplate and SpawnLocation alone: on first run `WorldBuilder` removes the default baseplate and disables the default spawn.

## 2. Script types
In Studio, a file's **name suffix tells you its type**. Drop the suffix and `.luau` when naming the object:

| File suffix | Studio object | Example file → object name |
|---|---|---|
| `*.server.luau` | **Script** | `Main.server.luau` → Script `Main` |
| `*.client.luau` | **LocalScript** | `Main.client.luau` → LocalScript `Main` |
| `*.luau` (other) | **ModuleScript** | `DataService.luau` → ModuleScript `DataService` |
| folder | **Folder** | `Services/` → Folder `Services` |

Paste each file's whole content into the matching object.

## 3. Exact hierarchy

```
ReplicatedStorage
└── Shared                         (Folder)
    ├── Config                     (Folder)
    │   ├── Arenas                 (ModuleScript)
    │   ├── Belts                  (ModuleScript)
    │   ├── Buildings              (ModuleScript)
    │   ├── Creatures              (ModuleScript)
    │   ├── Eggs                   (ModuleScript)
    │   ├── Fruits                 (ModuleScript)
    │   ├── GameConfig             (ModuleScript)
    │   ├── Katanas                (ModuleScript)
    │   ├── LiveOps                (ModuleScript)
    │   ├── Locations              (ModuleScript)
    │   ├── Rarities               (ModuleScript)
    │   ├── Sounds                 (ModuleScript)
    │   ├── Trails                 (ModuleScript)
    │   ├── Training               (ModuleScript)
    │   └── Upgrades               (ModuleScript)
    └── Util                       (Folder)
        ├── Format                 (ModuleScript)
        ├── Formulas               (ModuleScript)
        ├── JapaneseBuilder        (ModuleScript)
        ├── ModelBuilder           (ModuleScript)
        ├── Net                    (ModuleScript)
        ├── PlotGrid               (ModuleScript)
        ├── Signal                 (ModuleScript)
        └── Trajectory             (ModuleScript)
└── Assets                         (Folder, optional: your own 3D models - see docs/ASSETS.md)
    ├── Creatures                  (Folder)
    ├── Buildings                  (Folder)
    ├── Decor                      (Folder)
    └── Katanas                    (Folder)

ServerScriptService
└── Server                         (Folder)
    ├── Main                       (Script)        <- src/server/Main.server.luau
    ├── Services                   (Folder)
    │   ├── ActionService          (ModuleScript)
    │   ├── BossService            (ModuleScript)
    │   ├── BuildingService        (ModuleScript)
    │   ├── DataService            (ModuleScript)
    │   ├── EggService             (ModuleScript)
    │   ├── EquipmentService       (ModuleScript)
    │   ├── EventService           (ModuleScript)
    │   ├── ProgressionService     (ModuleScript)
    │   ├── QuestBus               (ModuleScript)
    │   ├── RewardService          (ModuleScript)
    │   ├── ShopService            (ModuleScript)
    │   ├── SlicingService         (ModuleScript)
    │   ├── TradeService           (ModuleScript)
    │   ├── TrainingService        (ModuleScript)
    │   └── WorldBuilder           (ModuleScript)
    └── Tests                      (Folder)
        └── SelfTest               (ModuleScript)

StarterPlayer
└── StarterPlayerScripts
    └── Client                     (Folder)
        ├── Main                   (LocalScript)   <- src/client/Main.client.luau
        ├── Controllers            (Folder)
        │   ├── AmbienceController (ModuleScript)
        │   ├── BossController     (ModuleScript)
        │   ├── BuildController    (ModuleScript)
        │   ├── FruitVisuals       (ModuleScript)
        │   ├── GrassController    (ModuleScript)
        │   ├── HatchReveal        (ModuleScript)
        │   ├── PetController      (ModuleScript)
        │   ├── SlicingController  (ModuleScript)
        │   ├── State              (ModuleScript)
        │   ├── TrainingGames      (ModuleScript)
        │   └── WorldController    (ModuleScript)
        └── UI                     (Folder)
            ├── Effects            (ModuleScript)
            ├── HUD                (ModuleScript)
            ├── Theme              (ModuleScript)
            ├── UIKit              (ModuleScript)
            ├── Viewport           (ModuleScript)
            └── Windows            (Folder)
                ├── BuildWindow    (ModuleScript)
                ├── EggsWindow     (ModuleScript)
                ├── IndexWindow    (ModuleScript)
                ├── PetsWindow     (ModuleScript)
                ├── RewardsWindow  (ModuleScript)
                ├── ShopWindows    (ModuleScript)
                ├── TeleportWindow (ModuleScript)
                ├── TradeWindow    (ModuleScript)
                ├── TrainingWindow (ModuleScript)
                └── UpgradesWindow (ModuleScript)
```

## 4. Things you do NOT create by hand
These are all created by code at runtime, so the scripts never depend on objects that don't exist:

| Object | Created by | Where |
|---|---|---|
| `Remotes` folder + 17 RemoteEvents + 2 RemoteFunctions | `Net.Setup()` in server `Main` | `ReplicatedStorage.Remotes` |
| The whole map (`FNS_World`), lighting, atmosphere | `WorldBuilder` | `Workspace`, `Lighting` |
| `leaderstats` | `ProgressionService` | each Player |
| Ninja Village plots + placed buildings (`FNS_Plots`) | `BuildingService` | `Workspace` |
| All ScreenGuis (`FNS_UI`, `FNS_FX`, `FNS_SliceHUD`, `FNS_Blade`, `FNS_Training`, `FNS_Hatch`) | client modules | `PlayerGui` |
| Katana / belt / trail on the character | `EquipmentService` | character |
| Pets, arena fruit | `PetController`, `FruitVisuals` (client only) | `Workspace.FNS_Pets`, `Workspace.FNS_LocalFruits` |

**Customising the map by hand:** press Play, select `Workspace.FNS_World`, copy it, stop the game, paste it into Workspace and edit it. `WorldBuilder` skips generation when `FNS_World` already exists. Keep the ProximityPrompts' attributes (`Action`, `Arena`, `Activity`, `Window`) and the `FNS_Gate` parts.

## 4b. Best graphics (optional, 30 seconds)
Some settings can only be changed in Studio, not by scripts:
1. **Explorer → Lighting → Properties → Technology = Future** (soft shadows + glowing lanterns at night).
2. **Explorer → Workspace → Terrain → Properties → Decoration = ✓** (animated grass blades). Only needed if the Output shows *"Enable grass blades manually"*.
3. **File → Studio Settings → Rendering → Editor Quality Level = Automatic or Level 21**, otherwise Studio may render the game in low quality.
4. Save the place (Ctrl+S). If you rebuild with `rojo build`, repeat steps 1-2 afterwards (or keep the place file and only use `rojo serve` to sync code).

## 5. Test checklist (Studio → Play, or Test → Start with 2 players)
- [ ] Output shows `Server ready`, `Client ready` and `[SelfTest] … 0 failed`.
- [ ] Walk north and step on a Sunny Orchard pad, then press E. The camera locks and fruit flies up.
- [ ] Drag with the mouse. With **Device Emulator → a phone**, swipe instead. Fruit splits, `+coins` pops up, coins rise.
- [ ] Slicing 3+ fruit quickly shows a **COMBO** banner. Slicing ⭐ starts **FRUIT FRENZY**. Hitting a 💣 removes a heart, and at 0 hearts the round summary appears.
- [ ] ⬆️ Upgrades: buy Speed, and walk speed in the HUD increases.
- [ ] ⚔️ Katanas: buy Iron (300) and confirm. The blade on your back changes and the swipe colour changes.
- [ ] 🏋️ Training: play each mini-game. Stats go up, cooldowns count down, and Training Level rises (watch for Yellow Belt at TL 2).
- [ ] Slice an egg → 🥚 Eggs shows a countdown → after 20 s **HATCH!** → reveal animation → creature follows you.
- [ ] 🐾 Creatures: Equip / Unequip / Equip Best / Release. 📖 Index marks discoveries.
- [ ] ✨ Trails: buy Neon (needs level 3). A trail appears and speed rises.
- [ ] 🏯 Village: buy a Stone Lantern (250) → 🔨 Place → the ghost turns green/red → click (PC) or tap + ✅ Place (phone). R rotates. 🧹 Pick up returns it to the inventory. Bonuses appear in the Village window.
- [ ] 🤝 Trade (Test → Start with 2 players): request → Accept → add a creature + coins → both Ready → both Confirm after 3 s → items swap. Any change resets Ready.
- [ ] 👹 Boss: in Studio the first boss appears ~45 s after Play (then every 5 min; live servers: every 30 min at :00/:30). Teleport → Boss Arena, press ⚔️ ATTACK / click / F, dodge the red circle, get rank + rewards.
- [ ] 🎉 Event: ~20 s after Play an event starts in Studio (panel on the right shows it with a timer).
- [ ] 🎁 Rewards: claim Day 1, playtime rewards after 5 min, quests progress while slicing / hatching / training.
- [ ] Grove gate is solid below level 10 and opens at level 10. Teleport to locked arenas is refused.
- [ ] Saving (published place with API access): stop, play again, and everything is restored, including the remaining egg timers.

**Fast testing tip:** to try late-game content quickly, temporarily raise `GameConfig.StartingCoins` (for example to `10000000`). It only affects *new* profiles, so test in an unpublished place or with API access off, where every session starts fresh. Set it back before publishing.
