# Architecture

## Principles
- **Server-authoritative.** The server owns coins, XP, levels, stats, items, eggs, creature rolls, training rewards and slicing rewards. The client only asks for things and renders them.
- **Data-driven.** All content and balance lives in `src/shared/Config`. Every derived number (walk speed, coin multiplier, spawn rate, hitbox…) comes from `Util/Formulas.luau`, which server and client share, so the UI always shows exactly what the server applies.
- **Asset-free.** The map, models, UI and effects are built from code with built-in Roblox textures and sounds, so nothing can break because of missing uploads.
- **Modular services.** Each server service has `Init()` (register remotes and actions) and `Start()` (connect events, start loops). `Main.server.luau` runs them in dependency order.

## Server services
| Service | Responsibility |
|---|---|
| `WorldBuilder` | Builds `Workspace.FNS_World` (spawn plaza, 3 arenas with pads, trench and gates, dojo with 5 stations and the belt shop, katana and trail shops, hatchery, scenery) and the lighting |
| `DataService` | Profile template, reconcile/sanitise, session-locked load/save, throttled replication (`DataChanged`), autosave, BindToClose |
| `ActionService` | The single `Action` RemoteFunction: whitelisted handlers, token-bucket rate limit, pcall isolation |
| `ProgressionService` | AddCoins / SpendCoins / AddXp (level-ups) / AddStat / AddTrainingXp, character WalkSpeed/JumpPower, freeze while slicing, leaderstats, Teleport action |
| `EquipmentService` | Katana on the back, belt on the waist, trail and particles; publishes the `EquippedCreatures` attribute for pet rendering |
| `ShopService` | BuyUpgrade (One / Ten / Max), Buy/Equip Katana, Belt, Trail |
| `EggService` | AddEgg (from slicing), HatchEgg, SkipEgg, HatchAllReady, Equip / Unequip / EquipBest / Release creatures, rarity rolls, "egg ready" notifications, server-wide announcements for Diamond+ hatches |
| `SlicingService` | Rounds, pad assignment, wave scheduler, slice validation, combos, frenzy, bombs and hearts, round summary |
| `TrainingService` | Start / Finish / Cancel training with one-time tokens, duration and score validation, cooldowns, rewards |

## Client modules
| Module | Responsibility |
|---|---|
| `Controllers/State` | Mirror of the profile and `Derived` stats, `Changed` signal, `Action()` / `Purchase()` wrappers with toasts |
| `Controllers/SlicingController` | Fixed camera, fruit simulation (`BulkMoveTo`), swipe hit-testing in screen space (mouse and multi-touch), blade trail, slicing HUD, summary |
| `Controllers/FruitVisuals` | Fruit, egg and bomb models, halves, pooled particle bursts, per-katana slice effects |
| `Controllers/TrainingGames` | The 5 mini-games and their runner (countdown, timer, input sinking, results) |
| `Controllers/HatchReveal` | Queued egg-shake, flash and reveal animation |
| `Controllers/PetController` | Renders everyone's pets locally from the player attribute, smooth follow, distance culling |
| `Controllers/WorldController` | ProximityPrompt routing, level gates (streaming-safe), first-time hints |
| `UI/*` | Theme, UIKit (buttons, windows, toasts, confirm dialog, grids, progress bars, per-panel auto-scaling), Effects (sounds, floating text, banners), HUD, Viewport, Windows |

## Remotes (created by `Net.Setup`, in `ReplicatedStorage.Remotes`)
| Remote | Direction | Payload | Server validation |
|---|---|---|---|
| `Action` (RF) | C→S | `(name, ...)` → `ok, message, extra` | whitelist, rate limit, per-handler type checks, pcall |
| `GetData` (RF) | C→S | → profile | read-only |
| `SlicingStart` | C→S | `arenaId` | string, arena exists, level requirement, alive, 1 s debounce |
| `SlicingStop` | C→S | – | – |
| `Slice` | C→S | `{spawnId…}` (≤ 12) | id spawned for this player, not yet sliced, inside its flight window (+ latency grace), not stunned, token bucket at the player's `SliceRate` |
| `DataChanged` | S→C | profile | – |
| `SpawnObjects` | S→C | `arenaId, pad, {Id,F,T,X0,Y0,Z,VX,VY,S}` | – |
| `SliceResult` | S→C | `{Id,Kind,Coins,Xp,Combo,EggAdded,Hearts}`, frenzy time | – |
| `SessionStarted` / `SessionEnded` | S→C | pad, hearts / summary | – |
| `Notify`, `StatPopup`, `LevelUp`, `HatchReveal` | S→C | feedback | – |

**Action names:** `Teleport`, `BuyUpgrade`, `BuyKatana`, `EquipKatana`, `BuyBelt`, `EquipBelt`, `BuyTrail`, `EquipTrail`, `HatchEgg`, `SkipEgg`, `HatchAllReady`, `EquipCreature`, `UnequipCreature`, `EquipBest`, `ReleaseCreature`, `StartTraining`, `FinishTraining`, `CancelTraining`, `GetTrainingCooldowns`.

## Slicing: why it is smooth *and* exploit-resistant
1. The server picks each object and its launch parameters, stamped with `workspace:GetServerTimeNow()`.
2. The client computes `position(t) = stage + (x0 + vx·t, y0 + vy·t − ½g·t², z)` every frame. The arc is deterministic, so no network traffic is needed in flight and there is no jitter.
3. The client projects each object to the screen and tests swipe segments against circles (fruit radius in pixels + an Agility-based bonus).
4. The server accepts an id only if it exists in that player's session, hasn't been sliced, and the current time is inside its flight window. It also limits the slice rate. An exploiter can at most auto-slice fruit that really exists for them, at their legitimate rate.

## Training validation
`StartTraining` checks requirements and cooldown and returns a GUID token plus a difficulty. `FinishTraining` needs the same token, at least `Duration − 1` seconds of real elapsed time, and a score clamped to `MaxScore`. Rewards scale with `score / Goal`, plus up to +50 % for exceeding the goal. A forged score is capped and still limited by cooldowns.

## Data schema (DataStore key `Player_<UserId>`, value `{ Data = profile, Lock = {JobId, Time}, SavedAt }`)
```lua
profile = {
  Version, Coins, Xp, Level,
  Stats = { Speed, Strength, Agility },
  TrainingLevel, TrainingXp,
  OwnedKatanas = { [id] = true }, EquippedKatana,
  OwnedBelts   = { [id] = true }, EquippedBelt,
  OwnedTrails  = { [id] = true }, EquippedTrail,   -- "" = none
  Creatures = { [uid] = { Id, Obtained } }, EquippedCreatures = { uid… },
  Discovered = { [creatureId] = true },
  Eggs = { { Uid, EggId, HatchAt } … },            -- HatchAt = unix time, so eggs incubate offline
  NextUid, Totals = { FruitsSliced, EggsHatched, BestCombo, CoinsEarned, BombsHit, TrainingsDone },
  LastJoin,
}
```
On load, profiles are **reconciled** (new fields are added for old saves) and **sanitised** (unknown items removed, numbers clamped, equipped items re-validated, pets trimmed to the slot count).

## Performance
- Fruit are client-only anchored parts moved with one `workspace:BulkMoveTo` call per frame. There is no physics and no replication.
- Particle bursts reuse pooled emitters (`Emit(n)`) instead of creating instances per slice. The blade trail uses 48 pooled frames.
- Pets are rendered locally with welded models (one root CFrame per pet), and pets farther than 220 studs aren't updated.
- The server runs one scheduler loop for all sessions at 20 Hz. Profile replication is throttled to about 6/s per player, and egg-ready checks run every 2 s.
- Trails use one Trail plus at most one low-rate emitter. All movement caps live in `GameConfig`.

## Edge cases handled
- A player leaves mid-round, mid-training or mid-save: sessions are cleaned up, the final save waits for any in-flight autosave, and the lock is released.
- A server crashes while holding a lock: the lock goes stale after `SessionLockTimeout`, and loads force-take it after about 30 s of waiting.
- A DataStore outage: the player is kicked with a friendly message instead of getting an empty profile that would overwrite their save.
- Egg slots are full: the egg converts to coins. The creature inventory is full: hatching is refused with a message, and the egg is kept.
- An arena's pads are all busy: players share a pad, which works because fruit is client-local.
- Respawning during a round ends it cleanly and restores the camera.
- StreamingEnabled: gates and prompts register when they stream in, and teleports pre-stream the destination.
- Double-click purchases: client busy guard plus server checks.
