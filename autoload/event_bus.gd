extends Node
## Globalna szyna zdarzeń symulatora.

signal message(text: String)
signal log_added(entry: Dictionary)
signal signal_selected(sig_id: String)
signal route_set(route: Dictionary)
signal route_released(route_id: int, emergency: bool)
signal sz_used(sig_id: String)
signal train_spawned(train)
signal train_arrived(train)
signal train_ready(train)
signal train_departed(train)
signal train_removed(train)
signal random_event_started(ev: Dictionary)
signal random_event_ended(ev: Dictionary)
signal random_event_acked(ev: Dictionary)
signal panel_changed(panel_name: String)
signal timetable_updated(source: String)
signal shunt_job_added(job: Dictionary)
signal shunt_job_done(job: Dictionary)
signal tutorial_finished
