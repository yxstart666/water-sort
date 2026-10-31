extends RefCounted
## Pointer factory; presentation only. Both tutorial hosts share exact V3 sources.
const Pointer=preload("res://scripts/water_sort/guide_pointer_v3.gd")
const HAND=preload("res://assets/colorpause_ui_20261030/guide_shell/sprites/hand_pointer.webp")
const RING=preload("res://scripts/water_sort/tap_ring_v3.gdshader")
static func create_pointer(scale_factor: float) -> Node2D:
 var node=Pointer.new();node.hand_texture=HAND;node.ring_shader=RING;node.scale=Vector2.ONE*scale_factor;node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;node.z_index=90;return node
