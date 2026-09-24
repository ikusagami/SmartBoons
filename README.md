# SmartBoons

SmartBoons is an REFramework mod for *Dragon's Dogma 2* that improves how Mage Pawns choose elemental Boons against supported enemies.

The mod never forces a Mage to cast a Boon. After the game AI has decided to cast Fire, Ice, or Thunder Boon, SmartBoons checks the relevant target and replaces the chosen Boon only when that Mage has a better configured Boon equipped.

## Installation

1. Install [REFramework](https://www.nexusmods.com/dragonsdogma2/mods/8).
2. Copy `SmartBoons.lua` and the `SmartBoons` folder to `<Dragon's Dogma 2>/reframework/autorun/`.
3. Launch the game and configure **SmartBoons** from the REFramework script menu.

The release `.zip` can also be installed through Fluffy Mod Manager.

## How it works

Each supported enemy has an ordered list of preferred Boons. SmartBoons selects the first Boon in that order which is equipped by the specific Mage Pawn performing the action.

For a priority of Ice, Thunder, then Fire:

- A Mage with Ice Boon uses Ice.
- A Mage without Ice but with Thunder uses Thunder.
- A Mage with only Fire keeps Fire.
- A Mage is never given a Boon it does not have equipped.

The game AI still decides whether and when casting a Boon is appropriate. SmartBoons only corrects the element after that decision; it does not interrupt actions or force an immediate cast.

## Boss and common-enemy targeting

Supported bosses always take precedence over common enemies. Dead bosses and bosses beyond the configured maximum distance from the Arisen are ignored.

When no eligible boss exists, SmartBoons may select a supported common enemy within its own maximum distance. Common enemies can have normal elemental preferences or no normal preference.

### Target selection modes

**Nearest boss** is the default and usually feels most natural. The closest eligible boss determines the Boon. If two bosses are within the configured distance tie range, rule priority breaks the tie.

Example: a Drake at 8 m and a Griffin at 45 m are eligible. The Drake determines the Boon, even if the Griffin has a higher priority.

Use this mode when the Mage should respond to the enemy the party is currently facing.

**Highest configured priority** selects the eligible boss with the highest configured priority. Distance is used only to break a tie between equal priorities.

Example: a Dragon with priority 110 is at 70 m and a Griffin with priority 40 is at 8 m. The Dragon determines the Boon while it is within the maximum boss distance.

Use this mode to establish a fixed hierarchy, such as Dragon > Drake > Griffin, during a multi-boss fight.

In both modes, common enemies are considered only when no eligible boss exists.

## Wet and Oiled rules

Every supported enemy can define a special Fire, Ice, or Thunder Boon while it is Wet or Oiled. These choices are fully configurable; neither status is permanently tied to one element.

Status rules take priority over the normal Boon order. If the configured special Boon is not equipped, SmartBoons falls back to the target's normal preference list.

SmartBoons reads the status on the selected target itself. Rain does not necessarily apply the game's Wet status to an enemy.

## Multiple Mages

Equipment is checked separately for every Mage Pawn, including hired Pawns. Different Mages can therefore choose different valid Boons against the same target.

## Default enemy mappings

Rules are manually configured for supported bosses and common enemies. Each rule can define:

- Target-selection priority.
- An ordered normal Boon preference.
- An optional Boon for Wet.
- An optional Boon for Oiled.

Enemy variants use their exact in-game CharacterID, allowing related variants to have independent rules when needed.

Some enemies intentionally have no default elemental preference. In those cases, SmartBoons preserves the Mage AI's original choice unless a configured Wet or Oiled rule applies.

Default mappings are manually tested and may be refined. Please report questionable mappings with the affected enemy variant and your test results.

## Configuration UI

Open **SmartBoons** from the REFramework script menu. The interface lets you:

- Enable or disable Boon replacement.
- Set maximum boss and common-enemy distances.
- Set the distance tie range.
- Choose nearest-first or priority-first target selection.
- Filter, sort, and search the rule list.
- Filter rules by their effective primary Boon: Fire, Ice, Thunder, or no primary Boon.
- Configure each rule's enabled state, priority, normal Boon order, Wet rule, and Oiled rule.
- Apply settings to all supported variants in an enemy family.
- Restore a selected rule, a family, or all rules to script defaults.

Changes apply immediately. Select **Save configuration** to write them to:

`reframework/data/SmartBoons_config.json`

If this file is missing or invalid, the built-in script defaults are used. Overrides that match the script defaults are removed automatically.

## Logs and Developer mode

Normal logs report hook installation and replacement failures. Successful replacements and cancellations are available in Developer mode.

Enable **Developer mode** for troubleshooting. It adds detailed target-selection, status, and Boon-candidate logs.

**Status discovery probe** is a separate Developer-mode option. It records status snapshots for the nearest living enemy and helps diagnose Wet, Oil, and related status interactions after a game update. Leave it disabled during normal play.

## Compatibility

SmartBoons should work alongside other mods unless they replace the Mage Pawn's Boon action logic, alter enemy CharacterIDs, or modify the same AI action packs.

Compatibility with Pawn AI, enemy AI, elemental-effect, and action-pack mods has not been broadly tested. Their behavior or load order may affect SmartBoons.

## Bug reports

Please include the SmartBoons, game, and REFramework versions; the Mage's equipped Boons; the target enemy and nearby enemies; relevant settings or `SmartBoons_config.json`; reproduction steps; expected and actual behavior; and relevant lines from `re2_framework_log.txt`.

Enable Developer mode only when normal logs do not provide enough information.

## What SmartBoons does not do

- It does not discover elemental weaknesses automatically.
- It does not force a Mage to cast a Boon.
- It does not interrupt unrelated AI actions.
- It does not apply, remove, or fake enemy statuses.
- It does not give a Mage a Boon that is not equipped.

## Files

Keep this structure intact when installing the mod:

```text
reframework/
└─ autorun/
   ├─ SmartBoons.lua
   └─ SmartBoons/
      ├─ BossRules.lua
      ├─ CommonRules.lua
      └─ Families.lua
```

- `SmartBoons.lua` contains the hooks, target selection, equipped-Boon checks, configuration, logs, and UI.
- `BossRules.lua` contains default boss rules.
- `CommonRules.lua` contains default common-enemy rules.
- `Families.lua` defines variants used by the family-preset UI.

All files are required. Do not rename the files or move the contents of the `SmartBoons` folder.
