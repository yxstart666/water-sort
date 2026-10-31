extends RefCounted

const FontPolicy=preload("res://scripts/ui_restore/font_policy.gd")
const DIRECTORY := "res://assets/ui_restore/gameplay_state_binding_v1/"
static var loaded_files: Dictionary = {}
static var variations: Dictionary = {}
static var errors: Array = []

static func _blocked_font(message: String) -> FontVariation:
	errors.append(message);push_error(message)
	var blank:=FontFile.new();blank.allow_system_fallback=false;blank.fallbacks=[]
	var result:=FontVariation.new();result.base_font=blank;return result

static func font(binding: String) -> FontVariation:
	if variations.has(binding):
		return variations[binding]
	var id := "latin" if binding == "latin" else "cjk"
	if binding not in ["latin", "cjk_face0", "cjk_face2"]:
		return _blocked_font("Unknown explicit font binding: " + binding)
	if not loaded_files.has(id):
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "manifest.json"))
		for item in manifest.assets:
			if item.id != id:
				continue
			var path: String = DIRECTORY + item.file
			var source := FontPolicy.load_verified(path,item.sha256)
			if source==null:
				return _blocked_font("Exact imported font validation failed: " + id)
			source.allow_system_fallback = false
			source.fallbacks = [FontPolicy.get_font("sc")] if id=="latin" else []
			# Render runtime glyphs above the largest authored canvas scale; do not enlarge a low-resolution glyph atlas.
			source.multichannel_signed_distance_field = true
			source.msdf_pixel_range = 16
			source.msdf_size = 128
			loaded_files[id] = source
	if not loaded_files.has(id):
		return _blocked_font("Exact font binary missing: " + id)
	var result := FontVariation.new()
	result.base_font = loaded_files[id]
	result.variation_face_index = 2 if binding == "cjk_face2" else 0
	variations[binding] = result
	return result

static func field(source_file: String, label_id: String, locale: String = "") -> Dictionary:
	var bindings: Array = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "label_font_bindings_and_sizes.json"))
	for item in bindings:
		if item.source_file == source_file and item.label_id == label_id and (locale.is_empty() or str(item.json_pointer).contains("/" + locale + "/")):
			return item.duplicate(true)
	errors.append("Exact field font binding missing: " + source_file + "/" + label_id + "/" + locale)
	return {}

# Visible-glyph bounds, not the font's generous CJK line box. This prevents
# Label's minimum height from pushing small numeric fields down or sideways.
static var ink_cache: Dictionary = {}
static func ink_bounds(value: String, typeface: Font, pixels: int) -> Rect2:
	var key := str(typeface.get_instance_id()) + ":" + str(pixels) + ":" + value
	if ink_cache.has(key): return ink_cache[key]
	var line := TextLine.new()
	line.add_string(value, typeface, pixels)
	var server := TextServerManager.get_primary_interface()
	var bounds := Rect2()
	var has_ink := false
	var advance := 0.0
	for glyph in server.shaped_text_get_glyphs(line.get_rid()):
		for repeat in range(int(glyph.repeat)):
			var glyph_size := Vector2i(int(glyph.font_size), 0)
			var extent := server.font_get_glyph_size(glyph.font_rid, glyph_size, glyph.index)
			if extent.x > 0 and extent.y > 0:
				var offset := server.font_get_glyph_offset(glyph.font_rid, glyph_size, glyph.index)
				var box := Rect2(Vector2(advance, 0) + glyph.offset + offset, extent)
				bounds = bounds.merge(box) if has_ink else box
				has_ink = true
			advance += float(glyph.advance)
	ink_cache[key] = bounds
	return bounds

static func center_label(label: Label, target: Rect2, minimum_pixels: int = 0) -> void:
	label.set_meta("ink_target_rect", target)
	label.clip_text = true # A translated caption may not grow its authored box.
	label.position = target.position
	label.size = target.size
	if label.text.contains("\n") or label.text.is_empty(): return
	var typeface := label.get_theme_font("font")
	var pixels := label.get_theme_font_size("font_size")
	var lower := minimum_pixels if minimum_pixels > 0 else maxi(14, int(pixels * 0.72))
	while pixels > lower and typeface.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x > target.size.x - 4:
		pixels -= 1
	label.add_theme_font_size_override("font_size", pixels)
	var ink := ink_bounds(label.text, typeface, pixels)
	var width := typeface.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var line_height := typeface.get_height(pixels)
	var actual_height := maxf(target.size.y, line_height)
	# Label vertically centers its line box, then places the baseline at ascent.
	var baseline := (actual_height - line_height) * 0.5 + typeface.get_ascent(pixels)
	label.position = target.get_center() - Vector2((target.size.x - width) * 0.5 + ink.get_center().x, baseline + ink.get_center().y)
	label.size = Vector2(target.size.x, actual_height)
	label.set_meta("centered_ink_bounds", Rect2(target.get_center() - ink.size * 0.5, ink.size))
