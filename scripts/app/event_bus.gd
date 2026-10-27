extends Node

## Lightweight signal hub. Domain systems emit compact semantic events here;
## screens listen and render. Events are presentation notifications, never the
## only record of state.

@warning_ignore("unused_signal")
signal activity_changed(activity: Dictionary)
@warning_ignore("unused_signal")
signal action_completed(info: Dictionary)
@warning_ignore("unused_signal")
signal item_gained(item_id: String, amount: int)
@warning_ignore("unused_signal")
signal item_lost(item_id: String, amount: int)
@warning_ignore("unused_signal")
signal xp_gained(skill: String, amount: int)
@warning_ignore("unused_signal")
signal level_up(skill: String, level: int)
@warning_ignore("unused_signal")
signal bank_changed()
@warning_ignore("unused_signal")
signal equipment_changed()
@warning_ignore("unused_signal")
signal state_changed()
@warning_ignore("unused_signal")
signal offline_summary(summary: Dictionary)
@warning_ignore("unused_signal")
signal notification(text: String, kind: String)
@warning_ignore("unused_signal")
signal profile_loaded()