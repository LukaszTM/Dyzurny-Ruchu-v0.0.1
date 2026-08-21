extends GutTest
## Testy blokady półsamoczynnej (docs/systemy/15 §1/§4): pozwolenie,
## pola Po/Ko/Poz, warunki wyprawienia.


func _block() -> BlockLine:
	return BlockLine.from_def({
		"id": "blk_t", "neighbour": "Lipno",
		"entry_signal": "A", "exit_signals": ["D1", "D2"],
	}, &"iza")


func test_wyprawienie_wymaga_pozwolenia_i_wolnego_odstepu() -> void:
	var block := _block()
	assert_true(block.can_dispatch().ok, "pozwolenie u gracza, odstęp wolny")
	assert_true(block.press("Poz").ok, "przekazanie pozwolenia sąsiadowi")
	var no_permission := block.can_dispatch()
	assert_false(no_permission.ok)
	assert_string_contains(no_permission.reason, "pozwolenie")
	block.give_permission_to_player()
	block.train_dispatched_by_player("111")
	var occupied := block.can_dispatch()
	assert_false(occupied.ok, "odstęp zajęty blokuje wyprawienie")
	assert_string_contains(occupied.reason, "zajęty")


func test_poz_nie_przechodzi_przy_zajetym_odstepie() -> void:
	var block := _block()
	block.train_entered_from_neighbour("111")
	assert_false(block.press("Poz").ok, "nie wolno przekazać pozwolenia na zajęty odstęp")
	assert_false(block.give_permission_to_player(), "ani otrzymać (przypadek brzegowy)")


func test_po_tylko_po_wyprawieniu() -> void:
	var block := _block()
	assert_false(block.press("Po").ok, "Po bez wyprawionego pociągu odrzucone")
	block.train_dispatched_by_player("111")
	assert_true(block.press("Po").ok)
	assert_true(block.po_locked)
	assert_false(block.press("Po").ok, "ponowne Po odrzucone (przypadek brzegowy)")
	block.released_by_neighbour()
	assert_false(block.occupied)
	assert_false(block.po_locked, "Ko sąsiada zwalnia pole początkowe")


func test_ko_tylko_po_przyjezdzie_calego_pociagu() -> void:
	var block := _block()
	assert_false(block.press("Ko").ok, "Ko bez pociągu odrzucone")
	block.train_entered_from_neighbour("222")
	assert_false(block.press("Ko").ok, "pociąg jeszcze na szlaku")
	block.train_arrived_at_player()
	assert_true(block.press("Ko").ok, "po przyjeździe całego pociągu Ko zwalnia odstęp")
	assert_false(block.occupied)
	assert_false(block.press("Ko").ok, "drugie Ko bez podstaw (przypadek brzegowy)")
