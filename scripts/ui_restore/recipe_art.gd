extends RefCounted
## Renders one delivered layer; no route, state or gameplay decisions.
const Art = preload("res://scripts/water_sort/p2_art.gd")
const ThemeConfig = preload("res://scripts/ui_restore/theme_config.gd")
static func layer(parent: Control, spec: Dictionary) -> Control:
	var node := Art.add_layer(parent, spec, ThemeConfig.asset(spec.source))
	node.set_meta("asset_id", spec.source)
	return node
static func box(values: Array) -> Rect2:
	return Rect2(values[0], values[1], values[2], values[3])
