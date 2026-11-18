# Свои 3D-модели (брейнроты, постройки, катаны)

Игра сама рисует всех брейнротов, постройки и катаны из деталей Roblox. Если вы положите **свою 3D-модель с правильным именем** в папку `assets`, игра автоматически возьмёт её вместо встроенной: в питомцах, превью, окне вылупления, деревне и на персонаже. Если модели нет, используется встроенная. Сломать ничего нельзя.

## Эффекты (частицы) — работают автоматически
Вокруг каждого брейнрота летят частицы цвета его редкости (у редких больше). У Мифических — огонь, у Космических — звёзды, у Секретных — «глитч». У **Shiny** — белые искры и свечение, у **Золотых** — золотые искры и золотой цвет, у **Радужных** — радужные частицы и переливающийся цвет.
**Это работает и для ваших настоящих 3D-моделей:** эффекты добавляются к любой модели из `assets/Creatures`, ничего дополнительно делать не нужно. Хотите свои эффекты — добавьте `ParticleEmitter` прямо внутрь своей модели, он тоже сохранится.

## Куда класть
| Что | Папка в проекте (Rojo) | Папка в Studio (без Rojo) |
|---|---|---|
| Брейнроты | `assets/Creatures/` | `ReplicatedStorage → Assets → Creatures` |
| Постройки деревни | `assets/Buildings/` | `ReplicatedStorage → Assets → Buildings` |
| Катаны | `assets/Katanas/` | `ReplicatedStorage → Assets → Katanas` |
| Деревья и кусты на карте | `assets/Decor/` | `ReplicatedStorage → Assets → Decor` |

⚠️ **Если вы собираете игру через `rojo build`, модели должны лежать в папке `assets/` как файлы `.rbxm`.** Если добавить их прямо в Studio, то при следующем `rojo build` файл `.rbxl` перезапишется и модели пропадут.

## Как добавить модель (пошагово)
1. В Studio вставьте модель: свою из Blender (**File → Import 3D**) или из **Toolbox / Creator Store**.
2. Если модель из интернета, раскройте её и **удалите все скрипты** (Script / LocalScript). Игра и сама их удаляет, но лучше проверить.
3. Убедитесь, что это один объект **Model**. Если это просто детали, выделите их и нажмите **Ctrl+G**.
4. **Переименуйте модель точно как Id** из таблицы ниже, например `StrawberrinoStompolino`.
5. Поверните модель «лицом» вперёд. В Roblox перёд — это сторона, куда смотрит синяя стрелка Front (ось −Z).
6. Размер не важен: игра сама подгонит модель под нужный размер.
7. **Для Rojo:** нажмите ПКМ по модели → **Save to File…** и сохраните `.rbxm` в нужную папку, например `assets/Creatures/StrawberrinoStompolino.rbxm`. Потом снова выполните `rojo build -o FruitNinjaSimulator.rbxl`.
   **Без Rojo:** перетащите модель в `ReplicatedStorage → Assets → Creatures` (папки создайте сами, если их нет).

## Id брейнротов
| Id | Имя | Редкость |
|---|---|---|
| `AppleCrunchito` | Apple Crunchito | Common |
| `OranginoRollini` | Orangino Rollini | Common |
| `BananitoBonkerino` | Bananito Bonkerino | Uncommon |
| `LemonzoSourpuccino` | Lemonzo Sourpuccino | Uncommon |
| `StrawberrinoStompolino` | Strawberrino Stompolino | Rare |
| `GrapelliWobblini` | Grapelli Wobblini | Rare |
| `WatermelonioChompatelli` | Watermelonio Chompatelli | Epic |
| `KiwiKaboomba` | Kiwi Kaboomba | Epic |
| `PineapploSpinnerino` | Pineapplo Spinnerino | Legendary |
| `MangolinoMoonwalko` | Mangolino Moonwalko | Legendary |
| `CoconuttoDiamantino` | Coconutto Diamantino | Diamond |
| `BlueberrinaCrystallina` | Blueberrina Crystallina | Diamond |
| `PeachyGoldorado` | Peachy Goldorado | Gold |
| `CherryTwinsyBling` | Cherry Twinsy Bling | Gold |
| `DragonfruttoFlamerino` | Dragonfrutto Flamerino | Mythical |
| `DurianzoStinkolossus` | Durianzo Stinkolossus | Mythical |
| `CosmicFruitzilla` | Cosmic Fruitzilla | Cosmic |
| `StarfruttoGalactico` | Starfrutto Galactico | Cosmic |
| `Glitchberry404` | Glitchberry 404 | Secret |
| `TheUnsliceable` | The Unsliceable | Secret |

## Id построек
`StoneLantern`, `PaperLantern`, `Bonsai`, `BambooGrove`, `SakuraTree`, `ZenGarden`, `KoiPond`, `ToriiGate`, `Bridge`, `Shrine`, `TeaHouse`, `BellTower`, `MinkaHouse`, `Pagoda`

Модель постройки ставится **низом на землю**, и игра подгоняет её под размер клеток на участке.

## Id декора (деревья на карте)
`SakuraTree`, `BigTree`, `Bush`, `Bamboo` — если положить модель с таким именем, **все** такие деревья/кусты на карте заменятся ею (размер подгоняется автоматически). Это самый быстрый способ сделать мир реалистичнее: найдите в Toolbox красивую сакуру (поиск «sakura tree» / «cherry blossom»), проверьте что внутри нет скриптов, назовите `SakuraTree` и сохраните в `assets/Decor/`.

## Id катан
`Wooden`, `Iron`, `Golden`, `Diamond`, `Fire`, `Lightning`, `Cosmic`, `Mythical`

Для катаны нужно чуть больше: у модели должен быть задан **PrimaryPart — рукоять**, а **лезвие должно смотреть вверх** (ось +Y).

## Важно про авторские права
Используйте только модели, которые вам разрешено использовать: свои, бесплатные из Creator Store или купленные с лицензией. Не копируйте персонажей из чужих игр, за это Roblox может удалить игру.

## Свои украшения на карте (папка `map`)
Всё, что лежит в `map`, при сборке попадает в **Workspace → MyDecor** и остаётся там при каждом `rojo build`. Игра сама закрепляет модели (Anchored) и удаляет из них скрипты.

1. Нажмите **Play** (карта строится только в игре).
2. **Toolbox** → найдите модель → вставьте, поставьте инструментами Move / Rotate / Scale.
3. Выделите модель → **Ctrl+C** → **Stop**.
4. В Explorer нажмите ПКМ по **Workspace** → **Paste Into** (или Ctrl+Shift+V) — модель встанет на то же место.
5. Сгруппируйте все свои украшения в папку (или одну модель) → ПКМ → **Save to File…** → сохраните в `map/` (например `MyDecor1.rbxm`).
6. Удалите их из Workspace (они теперь в файле) и пересоберите `rojo build` — украшения на месте.
