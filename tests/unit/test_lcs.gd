extends GutTest
## Testy LCS-lite (docs/systemy/14 §5): dwa posterunki, wspólny tick,
## mostek przekazujący pociągi po wspólnym szlaku.

const SET_PATH := "res://data/lcs/brzeziny-lipiny.json"


func test_zestaw_wczytuje_dwa_posterunki() -> void:
	var lcs := LcsWorld.new()
	var result := lcs.load_file(SET_PATH)
	assert_true(result["ok"], String(str(result["errors"])))
	assert_eq(lcs.posts.size(), 2)
	assert_eq(lcs.names[0], "Brzeziny")
	assert_eq(lcs.names[1], "Lipiny")
	assert_eq(lcs.links.size(), 1)


func test_polecenia_kierowane_do_wskazanego_posterunku() -> void:
	var lcs := LcsWorld.new()
	assert_true(lcs.load_file(SET_PATH)["ok"])
	for post: SimWorld in lcs.posts:
		post.rng.seed = 9
	assert_true(lcs.execute(0, &"route_start", {"id": "A"}).ok,
		"przebieg na posterunku 0")
	assert_true(lcs.execute(1, &"route_set", {"id": "A_t3"}).ok,
		"posterunek 1 (komputerowy) przyjmuje route_set")
	assert_false(lcs.execute(7, &"route_start", {"id": "A"}).ok,
		"nieistniejący posterunek = odmowa")
	# Stany są rozdzielne: przebieg z posterunku 0 nie istnieje na 1.
	assert_eq(lcs.posts[1].interlocking.get_route(&"A_t1").state,
		Const.RouteState.IDLE)


func test_mostek_przekazuje_pociag_miedzy_posterunkami() -> void:
	var lcs := LcsWorld.new()
	assert_true(lcs.load_file(SET_PATH)["ok"])
	for post: SimWorld in lcs.posts:
		post.rng.seed = 9
	# Brzeziny: wjazd t1; wyjazd C1 dopiero po zwolnieniu drogi ochronnej
	# A_t1 (izw2 wspólna — 90 s), więc ponawiany w pętli.
	assert_true(lcs.execute(0, &"route_start", {"id": "A"}).ok)
	var c1_set := false
	var transferred := false
	var spawned_at_b := false
	for i: int in 15000:
		lcs.tick(0.1)
		lcs.drain_events()
		if not c1_set and i % 50 == 0:
			c1_set = lcs.execute(0, &"route_start", {"id": "C1"}).ok
		if not transferred:
			var entry := lcs.posts[1].timetable.entry_by_nr("31601")
			if entry != null:
				transferred = true
				assert_eq(entry.from_station, "Kalina",
					"przekazany pociąg wchodzi od wspólnego sąsiada")
				assert_eq(entry.to_station, "Rogów")
				assert_eq(entry.track, "t1")
		else:
			for train: Train in lcs.posts[1].trains:
				if train.nr == "31601":
					spawned_at_b = true
			if spawned_at_b:
				break
	assert_true(transferred, "31601 trafił do rozkładu Lipin")
	assert_true(spawned_at_b, "31601 wjechał do świata Lipin")
	# Ten sam pociąg nie jest przekazywany drugi raz.
	var count := 0
	for entry: Timetable.Entry in lcs.posts[1].timetable.entries:
		if entry.nr == "31601":
			count += 1
	assert_eq(count, 1)


func test_zdarzenia_niosa_posterunek() -> void:
	var lcs := LcsWorld.new()
	assert_true(lcs.load_file(SET_PATH)["ok"])
	for post: SimWorld in lcs.posts:
		post.rng.seed = 9
	lcs.posts[1].pending_events.append({"type": &"alarm", "text": "próba"})
	lcs.tick(0.1)
	var found := false
	for event: Dictionary in lcs.drain_events():
		if event["type"] == &"alarm" and String(event.get("text", "")) == "próba":
			found = true
			assert_eq(int(event["post"]), 1)
			assert_eq(String(event["post_name"]), "Lipiny")
	assert_true(found, "zdarzenie z posterunku 1 oznaczone")
