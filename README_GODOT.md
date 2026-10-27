# MX-Idle — Godot project (README_GODOT)

A desktop idle RPG built in **Godot 4.7 (GDScript 2.0)**. This is the migration
target for the MX-Idle design plan. It is a **playable, editable build**
(Phases 0–3 of the master plan: app shell + Mining/Smithing/Fishing/Cooking +
Melee Combat), not a folder tree or mockup.

> Note on content values: the original TypeScript repository referenced by the
> plan was not available in this environment, so all item/recipe/deposit numbers
> here are **authored provisional balance** (`scripts/domain/content/content_data.gd`),
> not ports of the source values. IDs are stable; numbers are meant to be tuned
> in the plan's Phase 4. The XP curve is verified to give a coherent pacing
> (~0.3–0.5 h/level mid-game, ~38M XP total to level 99).

## Run it

- **Editor:** open the project and press Play (main scene: `res://scenes/boot/boot.tscn`).
- **CLI:** `godot --path . res://scenes/boot/boot.tscn`
- **Tests:** run `res://tests/unit/test_rules.gd` (11 tests: progression, content
  integrity incl. fishing/cooking/areas, save round-trip, inventory, mining loop,
  crafting reservation, equipment ownership, fishing loop, cooking, food/overeat,
  combat loop).

## What works (verified by running the game)

- **Boot → Profile Select → Game Shell** flow. Three independent character
  profiles: create, play, delete. The last character resumes automatically.
- **Device settings** (game scale, text size, volumes, reduced motion, tooltips,
  notifications) persisted separately from character saves.
- **Mining**: 11 deposits across 10 tiers, five-stage depth model, density/yield,
  pickaxe tier gates, XP/hour telemetry. Starts a running activity with a
  progress bar; locked tiers state exactly what unlocks them.
- **Smithing**: smelting + forging recipes across tiers with **input reservation**
  (inputs leave the bank on start and are returned on stop), automatic batch
  repeats, and stop-on-empty.
- **Bank**: searchable, rarity-coloured, large stacks, inline equip.
- **Equipment**: slot categories, equip/unequip with ownership rules (an item is
  never in the bank and equipped at the same time), aggregated stat display, and
  three dedicated food slots.
- **Fishing**: 10 weighted catch pools (species per tier), rod-tier gates,
  rarer finds, XP/hour telemetry.
- **Cooking**: cooks raw catches into food through the same reserved-input
  contract as Smithing.
- **Melee Combat** (Phases 3): 10 areas × (4 normal archetypes + an ELITE + a
  BOSS) = 60 enemies. Player-vs-enemy encounter view with sprites, HP bars, a
  distinct **Satiety** bar, the enemy's deterministic action sequence with the
  current action emphasised, Auto Combat and Auto Eat toggles, an eat-threshold
  slider and food slots. Resolver covers accuracy/evasion, critical hits,
  percentage-point resistances, the melee/ranged/magic style triangle, burn DoTs,
  multi-hit and stun actions, boss enrage phases (below 50% HP), gold and loot
  drops, enemy respawn, and persistent player HP.
- **Food sustain**: three food slots, Satiety, Auto Eat (HP threshold) and
  Overeat (stun + food lock + Satiety drain at full Satiety).
- **Persistence**: atomic-ish writes (`tmp` then replace), versioned JSON under
  `user://saves/`, profile index separate from settings, autosave every 15 s and
  on window close. Verified to survive a full restart.
- **Offline progress** through the *same* resolver as live play, surfaced as a
  "welcome back" summary toast (no double-awarding).
- **Notifications / offline summary** toast area in the shell.

## Architecture (simulation is authoritative)

```
scripts/
  app/            autoloads: EventBus, ContentRegistry, SettingsService,
                  SaveService, GameSession (simulation driver + autosave)
  domain/
    models/       CharacterState (typed, serialisable, validated)
    rules/        Progression (XP / level / tier maths)
    content/      ContentData (data-driven items, recipes, deposits)
  systems/        mining, smithing, inventory, equipment (pure RefCounted;
                  mutate state and RETURN event deltas — no UI, no signals)
  ui/             screen scripts (render state, call systems, never award)
scenes/
  boot/           boot flow
  shell/          GameShell (nav + top bar + screen host + toasts)
  screens/        home, mining, smithing, bank, equipment, settings, profiles
resources/themes/ main_theme.tres (shared, editable theme; dark #17212B palette)
tests/unit/       headless tests
```

Rules enforced:
- All UI is native Godot `Control` scenes — editable in the editor, no
  WebView/baked UI.
- Domain logic lives outside UI scripts; a progress bar reaching 100% never
  awards anything — the resolver does.
- Content is data-driven in one registry layer; no `match` statements in screens.

## Known gaps (honest status)

- **No dungeons** yet: areas contain 4 normals + an elite + a boss; chained
  dungeon encounters are not built (Phase 3 stretch / later polish).
- **Ranged and Magic combat (Phases 5–6)** are not playable — enemies can be
  ranged/magic (so resistances and the style triangle matter), but the player is
  melee-only.
- No player resistances yet (armour grants Defense/evasion only; enemy resistances
  and weapon damage-type choice are the meaningful preparation levers).
- No item icons (icons are generated colour-coded placeholders via `UiUtil.make_icon`).
  Combat sprites are two generated placeholder images reused for all enemies.
- No audio, no localization, no export presets, no `.tres` content resources yet
  (content is authored in `ContentData`; converting to `Resource` subclasses is a
  clean next step).
- No tooltip popover system beyond native tooltips (the combat enemy tooltip
  carries resistances/actions/drops).
- Balance is provisional (Phase 4).
- Offline summary is only shown when an activity was active at save time.

## Extending (next phases)

The same contracts are ready for the next systems: add content to `ContentData`,
add a `scripts/systems/<profession>/` resolver returning event deltas, add an
editable `scenes/screens/<profession>/` screen, and register it in
`game_shell.gd`'s `SCREEN_SCENES` map. Keep simulation authoritative.