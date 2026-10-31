extends RefCounted
## Explicit cross-project palette reuse only. No reward authority or input nodes.
const ROOT:="res://art/colorpause/ui_unified_20261030/"
const SMALL=preload(ROOT+"palette/palette_latest_original_120x112.png")
const LARGE=preload(ROOT+"palette/palette_large_display_450x443.png")
const BLANK=preload(ROOT+"stuck/assets/hero_card_blank.png")
static func make_hero(rect:Rect2)->Control:
	var host:=Control.new();host.name="ApprovedRefreshPaletteHero"
	host.position=rect.position;host.size=rect.size;host.mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Existing approved empty blue material, nine-sliced with its authored62px corners.
	# The old hero baked arrows into its background, so it cannot remain underneath.
	var plate:=NinePatchRect.new();plate.name="SharedApprovedHeroPlate";plate.texture=BLANK
	var factor:=rect.size.x/BLANK.get_width()
	plate.size=rect.size/factor;plate.scale=Vector2.ONE*factor
	for side in 4:plate.set_patch_margin(side,62)
	plate.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;host.add_child(plate)
	var icon:=TextureRect.new();icon.name="LargePalette"
	icon.texture=LARGE;icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size=rect.size*Vector2(.80,.80);icon.position=(rect.size-icon.size)*.5
	icon.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;host.add_child(icon)
	return host
