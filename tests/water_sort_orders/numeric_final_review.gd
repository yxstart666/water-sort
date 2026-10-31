extends "res://tests/water_sort_campaign50/memory_fixture.gd"
const Art=preload("res://scripts/ui_restore/numeric_art_label.gd")
func run()->void:
	var rows:Array=[]
	for family in ["home","levels","levels_gold","levels_locked","energy"]:
		var numeric=Art.new();numeric.size=Vector2(558,132) if family=="home" else (Vector2(324,105) if family=="energy" else Vector2(205,154));root.add_child(numeric)
		var face:=77.0 if family=="home" else (66.0 if family=="energy" else (94.0 if family=="levels_gold" else (86.0 if family=="levels_locked" else 91.0)))
		check(numeric.configure_family(family,face),"load independent PNG family "+family)
		for i in range(0 if family=="energy" else 1,31 if family=="energy" else 51):
			numeric.text="%d/30" % i if family=="energy" else ("第%d关" % i if family=="home" else str(i))
			check(numeric.is_complete(),"full value coverage "+family+numeric.text)
			var m:Dictionary=numeric.metrics();check(Rect2(Vector2.ZERO,numeric.size).grow(.01).encloses(m.ink_rect),"actual alpha bounds contained "+family+numeric.text)
			rows.append({"family":family,"text":numeric.text,"scale":m.scale,"ink":str(m.ink_rect)})
		numeric.queue_free();await process_frame
	var result:={"passed":failures.is_empty(),"checks":checks,"failures":failures,"cases":rows.size(),"rows":rows}
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("FINAL_NUMERALS "+JSON.stringify({"checks":checks,"failures":failures,"cases":rows.size()}));quit(0 if failures.is_empty() else 1)
