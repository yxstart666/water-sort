class_name GuidePointerV3
extends Node2D
## Visual-only: never synthesizes clicks, selects bottles, pours, or unlocks.
## Add under a CanvasLayer. supply_target returns bottle-body center IN THIS
## CANVAS coordinate space (convert host world coordinates before returning).
@export var hand_texture: Texture2D
@export var ring_shader: Shader
@export var canvas_width_dp: float = 88.0
@export var tip_uv := Vector2(0.208, 0.140)
@export var reduced_motion := false
# Candidate 390dp mapping from observed 417px reference: (-10,+21).
@export var lifted_tip_offset_dp := Vector2(9.0, -20.0)
var hand: Sprite2D
var ring: ColorRect
var ring_material: ShaderMaterial
var cycle: Tween
var supply_target: Callable
var phase_id := ""
var disposed := false
const PERIOD := 1.65

func _ready() -> void:
 hand = Sprite2D.new()
 hand.texture = hand_texture
 hand.centered = false
 add_child(hand)
 ring = ColorRect.new()
 ring.size = Vector2(48,48)
 ring.position = Vector2(-24,-24)
 ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
 ring.z_index = -1
 ring_material = ShaderMaterial.new()
 ring_material.shader = ring_shader
 ring.material = ring_material
 add_child(ring)
 hide()
 _reset_visual()

func show_phase(id: String, target_in_canvas: Callable) -> void:
 # Atomic phase replacement: no tween traveling through the old/other target.
 stop_guide()
 if id not in ["source", "target"]: return
 phase_id = id
 supply_target = target_in_canvas
 disposed = false
 if not _sync_target(): return
 show()
 _reset_visual()
 if not reduced_motion:
  cycle = create_tween().set_loops()
  cycle.tween_method(sample_cycle, 0.0, 1.0, PERIOD)

func _process(_delta: float) -> void:
 if visible and not _sync_target(): stop_guide()

func _sync_target() -> bool:
 if not supply_target.is_valid(): return false
 var point = supply_target.call()
 if not point is Vector2: return false
 position = point
 return true

func stop_guide() -> void:
 if cycle and cycle.is_valid(): cycle.kill()
 cycle = null
 supply_target = Callable()
 phase_id = ""
 hide()
 _reset_visual()

func set_motion_preference(enabled: bool) -> void:
 var old_id = phase_id
 var old_target = supply_target
 reduced_motion = enabled
 if visible: show_phase(old_id,old_target)

func _reset_visual() -> void:
 if not is_instance_valid(hand): return
 if hand_texture:
  hand.position = (Vector2.ZERO if reduced_motion else lifted_tip_offset_dp) - tip_uv * hand_texture.get_size() * (canvas_width_dp / hand_texture.get_width())
  hand.scale = Vector2.ONE * (canvas_width_dp / hand_texture.get_width())
 hand.rotation = 0.0
 if ring_material: ring_material.set_shader_parameter("active",0.0)

func sample_cycle(t: float) -> void:
 if not hand_texture: return
 var press := 0.0
 var rebound := 0.0
 if t >= 0.10 and t < 0.29: press = smoothstep(0.10,0.29,t)
 elif t >= 0.29 and t < 0.42: press = 1.0
 elif t >= 0.42 and t < 0.66:
  press = 1.0-smoothstep(0.42,0.66,t)
  rebound = sin((t-0.42)/0.24*PI) * 0.012
 var scale_factor := 1.0 - press*0.045 + rebound
 var angle := deg_to_rad(-10.0)*press
 var base := canvas_width_dp/hand_texture.get_width()
 hand.scale = Vector2.ONE * base * scale_factor
 hand.rotation = angle
 # Visible press travel: lifted fingertip starts right/up, lands exactly on target.
 # Reduced motion is a static hand touching the target, never floating.
 var tip_offset := lifted_tip_offset_dp * (1.0-press) if not reduced_motion else Vector2.ZERO
 hand.position = tip_offset-(tip_uv*hand_texture.get_size()*base*scale_factor).rotated(angle)
 var contact := t >= 0.29 and t <= 0.62 and not reduced_motion
 ring_material.set_shader_parameter("active",1.0 if contact else 0.0)
 ring_material.set_shader_parameter("progress",clampf((t-0.29)/0.33,0.0,1.0))

func _exit_tree() -> void:
 disposed = true
 if cycle and cycle.is_valid(): cycle.kill()
 supply_target = Callable()
