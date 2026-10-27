# MX-Idle — Godot project (README_GODOT)

A desktop idle RPG built in **Godot 4.7 (GDScript 2.0)**. This is the migration
target for the MX-Idle design plan. It is a **playable, editable vertical slice**
(Phase 0 + Phase 1 of the master plan), not a folder tree or mockup.

> Note on content values: the original TypeScript repository referenced by the
> plan was not available in this environment, so all item/recipe/deposit numbers
> here are **authored provisional balance** (`scripts/domain/content/content_data.gd`),
> not ports of the source values. IDs are stable; numbers are meant to be tuned
> in the plan's Phase 4. The XP curve is verified to give a coherent pacing
> (~0.3–0.5 h/level mid-game, ~38M XP total to level 99).

## Run it

- **Editor:** open the project and press Play (main scene: `res://scenes/boot/boot.tscn`).
- **CLI:** `godot --path . res://scenes/boot/boot.tscn`
- **Tests:** run `res://tests/unit/test_rules.gd` (7 tests: progression, content
  integrity, save round-trip, inventory, mining loop, smithing reservation,
  equipment ownership).

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
  never in the bank and equipped at the same time), aggregated stat display.
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

## Known gaps (honest status — this is Phase 0 + Phase 1 only)

- **Fishing + Cooking (Phase 2)** and **Combat (Phase 3)** are **not implemented**.
  Skills `fishing`, `cooking`, `attack`, `hitpoints` exist in state but have no
  content/screens yet.
- No combat, no bosses/dungeons/elites, no Ranged/Magic.
- No item icons (icons are generated colour-coded placeholders via `UiUtil.make_icon`).
- No audio, no localization, no export presets, no `.tres` content resources yet
  (content is authored in `ContentData`; converting to `Resource` subclasses is a
  clean next step).
- No tooltip/inspect popover system beyond native tooltips.
- `Fishing`, `Cooking`, `Combat` nav entries are intentionally absent (screens
  are only added when their phase lands).
- Offline summary is only shown when an activity was active at save time.

## Extending (next phases)

The same contracts are ready for the next systems: add content to `ContentData`,
add a `scripts/systems/<profession>/` resolver returning event deltas, add an
editable `scenes/screens/<profession>/` screen, and register it in
`game_shell.gd`'s `SCREEN_SCENES` map. Keep simulation authoritative.