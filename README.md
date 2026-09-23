# SmartBoons

An REFramework mod for Dragon's Dogma 2 that improves how Mage Pawns choose elemental Boons against mapped enemies.

The mod does not make a Mage cast a Boon on demand. Instead, once the game AI has already decided to cast a Fire, Ice, or Thunder Boon, the mod checks the relevant target and replaces that Boon with the best configured and equipped option.

## Installation

1. Install [REFramework](https://www.nexusmods.com/dragonsdogma2/mods/8).
2. Copy `SmartBoons.lua` and the `SmartBoons` folder to `<Dragon's Dogma 2>/reframework/autorun/`.
3. Launch the game and open the REFramework menu to configure **SmartBoons**.

**OR**

1. Download the `.zip` from the `<> Code` button on this page.
2. Drag the `.zip` into Fluffy Mod Manager and install it normally.

## How it works

Each mapped enemy has an ordered list of preferred Boons. The Mage uses the first Boon in that order that is actually equipped by that specific Pawn.

For example, if an enemy's order is Ice, Thunder, then Fire:

- A Mage with Ice Boon uses Ice.
- A Mage without Ice but with Thunder uses Thunder.
- A Mage with only Fire keeps Fire.
- A Mage is never given a Boon that is not equipped.

The game AI still decides when a Boon is worth casting. This mod only corrects which elemental Boon is used after that decision.

## Boss and common-enemy targeting

Mapped bosses always take precedence over common enemies. Dead bosses and bosses beyond the configured maximum distance from the Arisen are ignored.

When no relevant boss is present, the mod may use a mapped common enemy within its separate maximum distance from the Arisen. Common enemies can have normal elemental preferences or no normal preference at all.

Neutral enemies are still available in the configuration UI, allowing users to set Wet or Oiled rules for them without claiming an unconfirmed default weakness.

### Target selection modes

The target-selection setting changes which factor is evaluated first when multiple eligible enemies exist.

**"Nearest boss (default)"** is the most "natural" mode:

The mod selects the boss closest to the Arisen.
If two bosses are within the "distance tie range" of each other, the configured priority breaks the tie.

This is useful when you want the Mage to respond to the enemy the party is currently facing.

Example: Drake at 8m, Griffin at 45m → The Drake determines the Boon, even if the Griffin has higher priority.

**"Highest configured priority"** is the most "strategic" mode:

The mod selects the boss with the highest configured priority, provided it is within the "Max boss distance."

Distance is only used as a tie-breaker if priorities are equal.

This is useful when specific bosses should always determine the buff while in the fight, even if another boss is momentarily closer.

Example: Dragon (priority 110) at 70m, Griffin (priority 40) at 8m → Dragon determines the Boon.

In practice:

- Use **"Nearest boss"** for dynamic fights involving multiple bosses.

- Use **"Highest configured priority"** if you want to establish a fixed hierarchy—such as Dragon > Drake > Griffin—regardless of which one is closer.

In both modes, common enemies are only considered if no eligible boss exists.

## Wet and Oiled rules

Rules may define a special Fire, Ice, or Thunder Boon while the selected target is Wet or Oiled. Both status rules are fully configurable per enemy in the UI; neither status is permanently tied to one element.

The mod reads the status applied to the target itself. This does not imply that an enemy affected by the rain is wet. The rain does not constantly apply the "Wet" status.

If the configured special Boon is not equipped, it falls back to that enemy's normal Boon order.

Status rules take **priority** over the normal Boon order. These rules are applied at the Mage AI's next normal Boon opportunity; they do not force an immediate cast or interrupt another action.

## Multiple Mages

Equipment is evaluated individually for every Mage Pawn, including hired Pawns.

Different Mages can therefore make different valid choices against the same enemy according to their equipped skills.

## Default Enemy Mappings

SmartBoons includes manually configured rules for supported bosses and common enemies.

Each mapped enemy may define:

- A priority used during target selection.
- An ordered list of preferred elemental Boons.
- An optional Boon to use while the enemy is Wet.
- An optional Boon to use while the enemy is Oiled.

Enemy variants are mapped by their exact in-game CharacterID rather than only by their displayed name. This allows different variants of the same enemy family to have independent rules when necessary.

Some enemies intentionally have no default elemental preference. In these cases, SmartBoons preserves the Mage AI's original Boon choice unless a configured status rule, such as Wet or Oiled, applies.

All default elemental preferences were mapped manually based on testing. SmartBoons does not automatically determine elemental weaknesses, so incorrect or incomplete mappings are possible.

If you find a questionable default mapping, please report it.

## Compatibility

SmartBoons should work alongside other mods, provided they do not change an enemy's in-game CharacterID or replace the Mage Pawn's Boon decision/action logic.

Compatibility with mods that alter Pawn AI, enemy AI, elemental effects, or action packs has not been broadly tested. If another mod changes those systems, its load order or behavior may affect SmartBoons.

## Configuration UI

Open **SmartBoons** in the REFramework script menu. The interface lets you:

- Enable or disable Boon replacement.
- Set maximum boss and common-enemy distances.
- Set the distance tie range.
- Choose nearest-first or priority-first target selection.
- Filter the rule list to all enemies, bosses only, or common enemies only.
- Sort rules by effective priority, enemy name, or family. Family mode adds a family selector that narrows the enemy list to that family.
- Search by enemy name and optionally enable **Show custom rules only**.
- Configure each mapped enemy's enabled state, priority, normal Boon order, Wet rule, and Oiled rule.
- Apply the selected rule's settings to every explicitly mapped variant in a supported enemy family, or restore that family's defaults.
- Restore a selected rule or every rule to the script defaults.

Changes apply immediately. Click **Save configuration** to persist them to:

`reframework/data/SmartBoons_config.json`

If the file is missing or invalid, the built-in script defaults are used. Saving also removes overrides that no longer differ from the defaults, so `[Custom]` means a saved rule is meaningfully different.

## Logs and Developer mode

Normal logs retain the information useful for verifying gameplay behavior: selected target, Wet/Oiled state where applicable, the AI's original Boon candidate, and any replacement that occurred. Installation and replacement failures are also reported.

**Developer mode** enables reverse-engineering diagnostics such as discovered CharacterIDs, EnemyManager catalogs, AI schemas and surfaces, action-owner resolution, equipped-skill probes, and action-pack traces.

**Status discovery probe** is a separate Developer-mode option. It writes a status snapshot for the nearest living enemy once per second and is intended only for mapping status interactions such as Wet, Oil, and Freeze.

## Bug reports

Please include enough information to reproduce the issue:

- SmartBoons version, game version, and REFramework version.
- The Mage's equipped Boons and whether the Pawn is yours or hired.
- The enemy or enemies involved, plus their distance from the Arisen if relevant.
- Your relevant SmartBoons settings or `SmartBoons_config.json`.
- Clear steps to reproduce and what you expected versus what happened.
- The relevant lines from `re2_framework_log.txt`. Enable **Developer mode** only when asked or when normal logs do not show enough information.

For an incorrect default weakness, also include the enemy variant and how you tested the elemental result.

## What the mod does not do

- It does not identify enemy elemental weaknesses.
- It does not block Boons from the AI's list.
- It does not force a Mage to cast immediately.
- It does not interrupt unrelated AI decisions.
- It does not apply, remove, or fake enemy status effects.

## Files

Keep the following structure intact when installing or updating the mod:

```text
reframework/
└─ autorun/
   ├─ SmartBoons.lua
   └─ SmartBoons/
      ├─ BossRules.lua
      ├─ CommonRules.lua
      └─ Families.lua
```

- `SmartBoons.lua` is the entry script. It contains the AI hooks, target selection, equipped-Boon checks, configuration handling, logs, and UI.
- `BossRules.lua` contains the default mappings for bosses.
- `CommonRules.lua` contains the default mappings for common enemies.
- `Families.lua` defines the explicit enemy variants used by the family-preset UI.

All files are required. Do not move the contents of the `SmartBoons` folder beside the entry script or rename its files.
