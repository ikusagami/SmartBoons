# SmartBoons

An REFramework mod for **Dragon's Dogma 2** that improves how Mage Pawns choose elemental Boons against mapped enemies.

The mod does not make a Mage cast a Boon on demand. Instead, once the game AI has already decided to cast a Fire, Ice, or Thunder Boon, the mod checks the relevant target and replaces that Boon with the best configured and equipped option.

## Installation

1. Install [REFramework](https://www.nexusmods.com/dragonsdogma2/mods/8).
2. Copy `SmartBoons.lua` to `<Dragon's Dogma 2>/reframework/autorun/`.
3. Launch the game and open the REFramework menu to configure **SmartBoons**.

**OR**

1. Download the .zip from "<> Code" button in this page.
2. Be smart and drag the zip into [Fluffy Mod Manager](https://www.nexusmods.com/dragonsdogma2/mods/1).

## How it works

Each mapped enemy has an ordered list of preferred Boons. The Mage uses the first Boon in that order which is actually equipped by that specific Pawn.

For example, if an enemy's order is Ice, Thunder, then Fire:

- A Mage with Ice Boon uses Ice.
- A Mage without Ice but with Thunder uses Thunder.
- A Mage with only Fire keeps Fire.
- A Mage is never given a Boon that is not equipped.

The game AI still decides **when** a Boon is worth casting. This mod only corrects **which** elemental Boon is used after that decision.

## Boss and common-enemy targeting

Mapped bosses always take precedence over common enemies. Dead bosses and bosses beyond the configured maximum distance from the Arisen are ignored.

When no relevant boss is present, the mod may use a mapped common enemy within its separate maximum distance from the Arisen. Common enemies can have normal elemental preferences or no normal preference at all. Neutral enemies are still available in the configuration UI, allowing users to set Wet or Oiled rules for them without claiming an unconfirmed default weakness.

### Target selection modes

The target-selection setting changes which factor is evaluated first when multiple eligible enemies exist:

- **Nearest boss (default):** distance is the primary rule. If two targets are within the configured *Distance tie range*, priority decides between them.
- **Highest priority boss:** priority is the primary rule. Distance decides only when priorities are equal.

Example: with a Drake at 10 m and a Garm at 30 m, *Nearest boss* selects the Drake. If the two targets are only 10 m apart and the tie range is 15 m, priority breaks the tie. With *Highest priority boss*, the highest configured priority wins anywhere inside the maximum boss distance.

The same distance-and-priority logic is used when choosing among common enemies, but common enemies are considered only after no boss qualifies.

## Wet and Oiled rules

Rules may define a special Fire, Ice, or Thunder Boon while the selected target is Wet or Oiled. Both status rules are fully configurable per enemy in the UI; neither status is permanently tied to one element.

The mod reads the status applied to the target itself. It does not assume that global rain reaches a target inside a cave or under cover. If the configured special Boon is not equipped, it falls back to that enemy's normal Boon order.

Status rules take priority over the normal Boon order. These rules are applied at the Mage AI's next normal Boon opportunity; they do not force an immediate cast or interrupt another action.

## Multiple Mages

Equipment is evaluated individually for every Mage Pawn, including hired Pawns. Different Mages can therefore make different valid choices against the same enemy according to their equipped skills.

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

## What the mod does not do

- It does not identify enemy elemental weakness.
- It does not block Boons from the AI's list.
- It does not force a Mage to cast immediately.
- It does not interrupt unrelated AI decisions.
- It does not apply, remove, or fake enemy status effects.

## Files

The active script is `reframework/autorun/SmartBoons.lua`.
