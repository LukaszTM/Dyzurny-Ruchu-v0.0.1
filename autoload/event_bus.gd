extends Node
## Globalna szyna zdarzeń symulatora.

# komunikaty pulpitu
signal message(text: String, level: int)   # 0 info, 1 ostrzeżenie, 2 błąd
signal panel_state_changed

# urządzenia srk
signal element_selected(kind: String, id: String)
signal route_requested(route: Dictionary)
signal route_locked(route: Dictionary)
signal route_released(route: Dictionary, tryb: String)
signal signal_command(sig_id: String, cmd: String)
signal switch_moved(sw_id: String, pos: String)

# ruch
signal train_spawned(train)
signal train_arrived(train)
signal train_ready(train)
signal train_departed(train)
signal train_removed(train)

# rozkład / EDR / zdarzenia / łączność
signal timetable_updated(source: String)
signal edr_added(entry: Dictionary)
signal random_event_started(ev: Dictionary)
signal random_event_ended(ev: Dictionary)
signal random_event_reported(ev: Dictionary)
signal comms_call_added(call_: Dictionary)
signal comms_call_handled(call_: Dictionary)
signal comms_changed

# samouczek
signal tutorial_step(idx: int)
signal tutorial_finished
