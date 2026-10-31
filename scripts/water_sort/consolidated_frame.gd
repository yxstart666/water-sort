extends Control
## Shared textured chrome. No action or game state belongs here.
var kind := "panel"
var patch: NinePatchRect
var compact: TextureRect
func _ready()->void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 patch=NinePatchRect.new();patch.mouse_filter=Control.MOUSE_FILTER_IGNORE;patch.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 var base="res://assets/colorpause_ui_20261030/sprites/"
 patch.texture=load(base+("panel_normal_9slice_candidate.webp" if kind=="panel" else ("title_normal_9slice_candidate.webp" if kind=="title" else "cyan_normal_9slice_candidate.webp")))
 for edge in 4: patch.set_patch_margin(edge,230 if kind=="panel" else (350 if edge in [SIDE_LEFT,SIDE_RIGHT] else 120))
 add_child(patch)
 if kind=="button":
  compact=TextureRect.new();compact.texture=load(base+"cyan_normal_clean.webp");compact.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;compact.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;compact.mouse_filter=Control.MOUSE_FILTER_IGNORE;compact.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(compact)
 resized.connect(_fit);_fit()
func _fit()->void:
 if not is_instance_valid(patch): return
 if is_instance_valid(compact):
  var compact_mode:=size.x<400.0
  compact.visible=compact_mode;compact.size=size;patch.visible=not compact_mode
  if compact_mode:return
 var factor: float=minf(0.4,minf(size.x/470.0,size.y/470.0)) if kind=="panel" else minf(0.29,minf(size.x/720.0,size.y/250.0))
 factor=maxf(0.001,factor);patch.size=size/factor;patch.scale=Vector2.ONE*factor
