extends Button
## Extend the original Button's hit test only. Godot owns pressed state, input
## capture, signal order, disabled/focus/keyboard behavior and node lifecycle.
## Rect, anchors, children and artwork are never changed.
const MINIMUM_PIXELS:=44.1
static func attach(button:Button)->void:
 var extension:Script=load("res://scripts/ui_restore/touch_hit.gd")
 if button.get_script()==extension:return
 # Current factories create plain Buttons. Never replace a custom behavior.
 if button.get_script()!=null:
  push_error("TouchHit refuses to replace an existing Button script: "+str(button.get_path()))
  return
 button.set_script(extension)
 button.set_meta("touch_native_hit",true)
func _has_point(point:Vector2)->bool:
 # Disabled Buttons retain native behavior in their original rect, but must
 # immediately stop intercepting the added area (no process-frame mirror).
 if disabled:return Rect2(Vector2.ZERO,size).has_point(point)
 return effective_hit_rect().has_point(point)
func effective_hit_rect()->Rect2:
 if not is_inside_tree():return Rect2(Vector2.ZERO,size)
 var window:=get_window()
 var transform:=window.get_final_transform()*get_global_transform_with_canvas()
 if is_zero_approx(transform.determinant()):return Rect2(Vector2.ZERO,size)
 var local_offset:Vector2=get_meta("touch_local_offset",Vector2.ZERO)
 var rect:Rect2=transform*Rect2(local_offset,size)
 var minimum:=preload("res://scripts/ui_restore/touch_units.gd").minimum_window_pixels()
 var extent:=Vector2(maxf(minimum,rect.size.x),maxf(minimum,rect.size.y))
 var target:=Rect2(rect.get_center()-extent*.5,extent)
 var bounds:Rect2=window.get_final_transform()*window.get_visible_rect()
 target.position.x=clampf(target.position.x,bounds.position.x,bounds.end.x-target.size.x)
 target.position.y=clampf(target.position.y,bounds.position.y,bounds.end.y-target.size.y)
 return transform.affine_inverse()*target
