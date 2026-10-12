# SmartBoons

SmartBoons is an REFramework mod for *Dragon's Dogma 2* that improves how Mage Pawns choose elemental Boons using the selected enemy's current Fire, Ice, and Thunder multipliers.

After the game AI decides to cast a Boon, SmartBoons checks the target and the casting Mage's equipped skills. It can replace the chosen element with the enemy's general elemental preference or an enabled Wet/Oil priority.

The game still decides whether and when to cast. SmartBoons never gives a Mage a Boon it does not have equipped.

## Installation

1. Install [REFramework](https://www.nexusmods.com/dragonsdogma2/mods/8).
2. Copy `SmartBoons.lua` and the `SmartBoons` folder to `<Dragon's Dogma 2>/reframework/autorun/`.
3. Launch the game and open **SmartBoons** from the REFramework script menu.

Keep both modules inside the `SmartBoons` folder. If installing while the game is running, reload scripts in REFramework or restart the game.

## How it works

SmartBoons reads the selected enemy's current elemental multipliers across its available data regions. Each region contributes equal influence:

- The element with the highest multiplier receives a first-place vote.
- Elements tied for first place share that vote.
- Second-place votes break equal first-place totals and help rank the remaining equipped candidates.
- Regions with equal Fire, Ice, and Thunder multipliers contribute no preference.

The highest-ranked equipped Boon is selected separately for each Mage. A larger multiplier does not give a region extra vote weight.

For example, if three informative regions favor Ice and one favors Thunder:

- A Mage with Ice and Thunder uses Ice.
- A Mage without Ice but with Thunder uses Thunder.
- A Mage with only Fire keeps Fire.

If the current Boon ties for the best equipped choice, it is retained. Other unresolved ties use a stable Fire, Ice, then Thunder order. When elemental data is unavailable or provides no preference, the Mage AI's original choice is kept unless an enabled status rule applies.

The target and its current data are checked at each Boon opportunity. A change in nearby enemies or enemy state can therefore change the next recommendation. SmartBoons does not force an immediate cast or immediately replace an active enchantment.

## Boss and common-enemy targeting

SmartBoons considers living enemies within the configured distance from the Arisen. Bosses are identified through the game's own boss flag.

1. The closest eligible boss determines the Boon.
2. If no boss is eligible, the closest eligible common enemy determines the Boon.

Default maximum distances are **50 m for bosses** and **25 m for common enemies**. Dead enemies, enemies outside their range, and enemies without a usable position are ignored. If a boss flag is unavailable, the enemy is considered common.

For example, a boss at 30 m takes precedence over a common enemy at 5 m. Between two eligible bosses at 8 m and 45 m, the boss at 8 m determines the Boon.

Only the selected enemy's elemental preference and statuses are considered. With three common enemies that favor different elements, the closest one determines the recommendation; their weaknesses are not combined.

## Wet and Oiled rules

Status priorities are optional and apply to the same selected enemy before regional voting. **Both are ignored by default.**

### When Wet

Choose one option:

- **Ice:** prioritize Ice Boon if that Mage has it equipped.
- **Thunder:** prioritize Thunder Boon if that Mage has it equipped.
- **Ignore** (default): use the normal regional preference.

Wet prioritizes only the selected element. If that Boon is not equipped, SmartBoons returns to regional voting, which may select any equipped element, including Fire.

### When Oiled

Enable **When Oiled: prioritize Fire** to prioritize Fire Boon against an Oiled target. This option is **disabled by default**.

If Fire is not equipped or the option is disabled, SmartBoons uses the normal regional preference.

SmartBoons reads the actual status on the target. Rain alone does not trigger the Wet rule. If the status cannot be read, no status priority is applied. A recognized status can select its equipped Boon even when elemental-region data is unavailable.

These rules affect the next normal Boon opportunity. They do not apply, remove, or simulate enemy statuses.

## Multiple Mages

Equipment is checked separately for every Mage Pawn, including hired Pawns. Different Mages can therefore choose different Boons against the same target, depending on the skills each one has equipped.

## Automatic enemy evaluation

Enemies are evaluated directly from their available game data. No manually registered enemy IDs are required, so new enemies and variants can be evaluated when their elemental-region data is readable.

The recommendation represents the enemy's general regional preference. Every informative region has equal influence; the mod does not estimate which body part will be hit or how much total damage a particular attack will deal.

## Configuration UI

Open **SmartBoons** from the REFramework script menu.

| Option | Default | Behavior |
| --- | --- | --- |
| Enable Boon replacement | Enabled | Allows SmartBoons to adjust the chosen Boon. |
| Max boss distance | 50 m | Maximum boss distance from the Arisen. |
| Max common enemy distance | 25 m | Maximum common-enemy distance from the Arisen. |
| When Wet | Ignore | Prioritize Ice, prioritize Thunder, or ignore Wet. |
| When Oiled: prioritize Fire | Disabled | Prioritize equipped Fire against an Oiled target. |
| Developer mode (diagnostic logs) | Disabled | Enable detailed target and decision logs. |

All changes apply immediately and are saved automatically to:

`reframework/data/SmartBoons_config.json`

Enable, distances, Wet/Oil options, and Developer mode are remembered after restarting the game or reloading scripts. A missing or invalid configuration uses the built-in defaults.

If saving fails, changes remain active for the current session. The menu shows a message and SmartBoons retries the save, including while the menu is closed.

## Logs and Developer mode

Normal logs report hook installation and failures. Enable **Developer mode** for detailed Boon-candidate and replacement logs.

Diagnostic logs include:

- The casting Pawn and the selected enemy's game name and ID.
- Boss/common classification and distance from the Arisen.
- Wet/Oil readings and any applied status priority, when those rules are enabled.
- Regional first- and second-place votes when regional voting is used.
- The original and recommended Boons, and whether the choice was kept or replaced.

If a game name is unavailable, the enemy ID is shown. `ActInter pack argument replaced` confirms a replacement at dispatch; it does not confirm that the cast finished.

## Compatibility

Other mods that change Mage Pawn Boon decisions, enemy elemental data, or the same AI action packs may affect SmartBoons' behavior.

Compatibility with Pawn AI, enemy AI, elemental-effect, and action-pack mods has not been broadly tested.

## Bug reports

Please include:

- SmartBoons, game, and REFramework versions.
- The casting Mage's equipped Boons.
- The target enemy and other nearby enemies.
- Relevant settings or `SmartBoons_config.json`.
- Reproduction steps, expected behavior, and actual behavior.
- Relevant lines from `re2_framework_log.txt`.

Enable Developer mode to capture the selected target and the reason for the Boon choice.

## What SmartBoons does not do

- Force a Mage to cast a Boon or interrupt unrelated actions.
- Give a Mage an unequipped Boon.
- Apply, remove, or simulate enemy statuses.
- Combine the weaknesses of multiple nearby enemies.
- Weight regions by multiplier magnitude, part HP, accessibility, or recent hits.

## Files

Keep this structure intact when installing the mod:

```text
reframework/
|-- autorun/
|   |-- SmartBoons.lua
|   `-- SmartBoons/
|       |-- Runtime.lua
|       `-- GeneralPreference.lua
`-- data/
    `-- SmartBoons_config.json   (saved automatically)
```

- `SmartBoons.lua` contains configuration, UI, status priorities, logging, and the Boon replacement hook.
- `Runtime.lua` reads enemies, names, boss classification, statuses, elemental regions, and the casting Mage's equipment.
- `GeneralPreference.lua` contains the regional voting policy.

All three Lua files are required. Keep their names and folder structure intact. The configuration file is created when an option is changed and saved successfully.
