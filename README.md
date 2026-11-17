# 🍉 Fruit Ninja Simulator (Roblox)

A complete, playable Roblox simulator set in a Japanese ninja world: **Fruit-Ninja-style slicing** + stat progression + katanas, belts and trails + **interactive training mini-games** + **eggs that hatch into fruit "brainrot" creatures** across 10 rarities. Everything is written in Luau and generated from code — the map, the UI and every model — so the game runs from a blank Baseplate with no uploaded assets.

## Features

| System | What's in it |
|---|---|
| ⚔️ Slicing | 3 arenas (Sunny Orchard, Tropical Grove, Cosmic Garden), 12 fruits, Golden Apple, Frenzy Star, bombs, 5 egg types. Fixed Fruit Ninja camera, mouse **and** multi-touch swipes, combos, frenzy mode, hearts, round summary |
| 📈 Progression | Coins, XP, levels (level-up coin rewards), Speed / Strength / Agility upgrades with rising prices (x1 / x10 / MAX), Training Level, arena unlocks at level 10 and 25, creature slots at levels 8 / 20 / 35 |
| 🗡️ Katanas | 8 katanas (Wooden → Mythical): coin multiplier, slice rate, hitbox size, unique blade look, swipe colour and slice burst effect (wood, sparks, shine, fire, lightning, cosmic, mythic) |
| 🥋 Belts | 10 belts (White → Cosmic) that need a Training Level; speed + training multipliers; worn on the character |
| 🏋️ Training | 5 mini-games: Arrow Rush (speed), Power Lift (strength), Reflex Targets (agility), Dummy Slice (katana), Master Gauntlet (special). Scaling difficulty, cooldowns, grades |
| 🥚 Eggs & creatures | Slice eggs → pending egg with a live countdown (20 s – 10 min) → hatch reveal animation. 20 original creatures, 10 rarities (Common → Secret), passive bonuses, equip / equip best / compare / release, collection index with undiscovered "???" entries |
| ✨ Trails | 10 trails with colours, particles and speed multipliers |
| 🏯 Ninja Village | Japanese-style world (torii, pagoda, sakura, lanterns, bell tower, koi pond, zen garden, Mount Fuji). Every player gets a plot and builds 14 Japanese buildings on a grid (ghost preview, rotate, pick up) for passive bonuses |
| 🤝 Trading | Player-to-player trades of creatures and coins: request → offer → Ready → Confirm with a safety countdown; validated and saved by the server |
| 🎨 Custom models | Drop your own 3D models into `assets/` and they replace the procedural creatures, buildings or katanas (see `docs/ASSETS.md`) |
| 🖥️ UI | HUD (level, XP, coins, speed, katana, belt, trail), 9 menus, purchase confirmations, toasts, stat popups, level-up banners. Scales for phones, tablets and PC |
| 💾 Saving | DataStore with session locking, `UpdateAsync`, retries, autosave, save on leave / shutdown, Studio offline fallback |
| 🛡️ Security | Server-authoritative currency, rewards, purchases, upgrades, hatching and progression; validated remotes, rate limits |

## Quick start

### Option A — Rojo (recommended)
1. Install [Rojo](https://rojo.space) 7.x (or run `aftman install`, which reads `aftman.toml`) and the Rojo Studio plugin.
2. In this folder: `rojo serve`
3. Open a new **Baseplate** place in Roblox Studio → Rojo plugin → **Connect**.
4. Press **Play**. The world builds itself, and the Output shows `[Fruit Ninja Simulator] Server ready.` and `[SelfTest] N passed, 0 failed`.

To produce a place file instead: `rojo build -o FruitNinjaSimulator.rbxl`.

### Option B — copy into Studio by hand
Follow [`docs/STUDIO_SETUP.md`](docs/STUDIO_SETUP.md): it lists every Script, LocalScript and ModuleScript, its exact location and type.

### Enable saving
Saving needs a **published** place: *File → Publish to Roblox*, then *Game Settings → Security → Enable Studio Access to API Services*. Without that, the game still runs, starts every player with a fresh profile and doesn't save (a warning is printed).

## Project layout

```
default.project.json          Rojo mapping (src/* -> Roblox services)
src/
  shared/   -> ReplicatedStorage.Shared   (used by server AND client)
    Config/   all balance data: Fruits, Katanas, Belts, Trails, Creatures, Rarities, Eggs, Arenas,
              Training, Upgrades, Locations, Sounds, GameConfig
    Util/     Formulas (all derived stats), Trajectory, Net (remotes), ModelBuilder, Format, Signal
  server/   -> ServerScriptService.Server
    Main.server.luau          bootstrap (creates remotes, starts services)
    Services/                 DataService, ActionService, ProgressionService, EquipmentService,
                              ShopService, EggService, SlicingService, TrainingService, WorldBuilder
    Tests/SelfTest.luau       config + formula checks (Studio only)
  client/   -> StarterPlayer.StarterPlayerScripts.Client
    Main.client.luau          bootstrap
    Controllers/              State, SlicingController, FruitVisuals, TrainingGames, HatchReveal,
                              PetController, WorldController
    UI/                       Theme, UIKit, Effects, Viewport, HUD, Windows/*
assets/     -> ReplicatedStorage.Assets   (optional custom models: Creatures/, Buildings/, Katanas/)
docs/
  ASSETS.md                   how to use your own 3D models (Russian)
  ARCHITECTURE.md             how the systems fit together, remotes, security model, data schema
  STUDIO_SETUP.md             manual placement guide + test checklist
```

## How to play
1. Spawn in the plaza. Signs point to **Arenas (north)**, **Dojo (east)**, **Shops (west)** and **Hatchery (south)**. The 🗺️ Teleport menu goes anywhere you've unlocked.
2. Step on a glowing pad in **Sunny Orchard** and press **E** (or tap the prompt).
3. **Hold the mouse and drag**, or **swipe with your finger**, through the fruit. Chain slices for combos, slice ⭐ for Fruit Frenzy, and avoid 💣 (3 hearts per round).
4. Spend coins in ⬆️ Upgrades, ⚔️ Katanas and ✨ Trails. Train at the Dojo for free stats and Training Levels, which unlock 🥋 Belts.
5. Slice 🥚 eggs, then hatch them in 🥚 Eggs (they keep incubating while you're offline). Equip creatures in 🐾 Creatures and complete the 📖 Index.

## Extending
All content is data-driven. For example, to add a katana, add one entry to `src/shared/Config/Katanas.luau`; the shop, saving, equipment visuals and bonuses pick it up automatically. The same goes for fruits, eggs, creatures, belts, trails, arenas and training. Run Play in Studio afterwards: SelfTest reports any broken references.

## Development stages
The game was built in the requested order, and each stage was playable before the next:
1. Core slicing and arena → 2. Currency, XP, levels, upgrades → 3. Katanas, belts, equipment bonuses → 4. Training → 5. Eggs, hatching, creatures, rarities, index → 6. Trails and speed multipliers → 7. UI polish → 8. DataStore saving → 9. Optimisation and edge cases (see `docs/ARCHITECTURE.md` → *Performance* and *Edge cases*).
