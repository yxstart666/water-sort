extends RefCounted
## Presentation substitutions only. A test can replace one material across views.
const ROOT := "res://assets/colorpause_ui_20261030/"
const INK := Color("0963bd")
static var material_overrides: Dictionary = {}
static func asset(relative_path: String) -> String:
	return ROOT + str(material_overrides.get(relative_path, relative_path))
