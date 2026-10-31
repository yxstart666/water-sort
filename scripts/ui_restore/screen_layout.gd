extends Node
## Window/safe-area presentation boundary. Never changes rule/world coordinates.
## A CanvasLayer carries the game uniformly: route/world caches remain1080x1920.
const DESIGN:=Vector2(1080,1920)
const BACKGROUND=preload("res://art/reference2-delivery-20261024/reference2_background_cleanplate_v1/assets/background_native_940x1672.png")
var host:Control
var game_layer:CanvasLayer
var background:TextureRect
var safe_rect:=Rect2()
var window_rect:=Rect2()
var _last_rect:=Rect2()
var safe_override_pixels:=Rect2() # Test injection only; no production switch.
var game
var _overlay_id:=0

func _ready()->void:
 name="ScreenLayout"
 get_viewport().set_meta("screen_layout",self)
 var back_layer:=CanvasLayer.new();back_layer.name="FullWindowBackground";back_layer.layer=-2;add_child(back_layer)
 background=TextureRect.new();background.name="ApprovedBackgroundCover";background.texture=BACKGROUND
 background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 background.mouse_filter=Control.MOUSE_FILTER_IGNORE;background.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 back_layer.add_child(background)
 game_layer=CanvasLayer.new();game_layer.name="GameDesignCanvas";game_layer.layer=-1;add_child(game_layer)
 host=get_parent();host.mouse_filter=Control.MOUSE_FILTER_IGNORE
 refresh_metrics()

func _exit_tree()->void:
 if get_viewport().get_meta("screen_layout",null)==self:get_viewport().remove_meta("screen_layout")

func mount_game(value:Control)->void:
 game=value
 game_layer.add_child(game)
 game.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);game.position=Vector2.ZERO;game.size=DESIGN
 _apply_game()

func _process(_delta:float)->void:
 refresh_metrics()
 if is_instance_valid(game):
  _dock_game()
  if game.has_method("refresh_bottle_layout_if_idle"):game.refresh_bottle_layout_if_idle()
  var id:int=game.overlay.get_instance_id() if is_instance_valid(game.overlay) else 0
  if id!=_overlay_id:
   _overlay_id=id
   if id!=0 and game.overlay.has_method("_fit"):game.overlay._fit()

func refresh_metrics()->void:
 window_rect=get_viewport().get_visible_rect()
 var physical:=Rect2(Vector2.ZERO,Vector2(get_window().size))
 var safe_pixels:=physical
 if safe_override_pixels.has_area():safe_pixels=physical.intersection(safe_override_pixels)
 elif OS.get_name() in ["Android","iOS"]:
  var area:=Rect2(DisplayServer.get_display_safe_area())
  # Native display coordinates -> client coordinates, then logical canvas.
  area.position-=Vector2(DisplayServer.window_get_position())
  if area.has_area():safe_pixels=physical.intersection(area)
 safe_rect=get_window().get_final_transform().affine_inverse()*safe_pixels
 safe_rect=safe_rect.intersection(window_rect)
 background.position=window_rect.position;background.size=window_rect.size
 if safe_rect!=_last_rect:
  _last_rect=safe_rect
  _apply_game()
  if is_instance_valid(host.get("home")):host.home._fit()
  for key in ["ad_dialog","p1_confirmation","energy_popup"]:
   var dialog=host.get(key)
   if is_instance_valid(dialog) and dialog.has_method("_fit"):dialog._fit()

func _apply_game()->void:
 var k:=minf(safe_rect.size.x/DESIGN.x,safe_rect.size.y/DESIGN.y)
 game_layer.transform=Transform2D(0,Vector2.ONE*k,0,safe_rect.get_center()-DESIGN*k*.5)
 if is_instance_valid(game):
  _dock_game()
  if is_instance_valid(game.overlay) and game.overlay.has_method("_fit"):game.overlay._fit()

func _dock_game()->void:
 var available:Rect2=game_layer.transform.affine_inverse()*safe_rect
 var top:=Vector2(0,available.position.y)
 var bottom:=Vector2(0,available.end.y-DESIGN.y)
 for key in ["Level","StepValue","TimeValue"]:
  if game.labels.has(key):dock(game.labels[key],top)
 for key in ["Reference2_title","Reference2_step","Reference2_step_icon","Reference2_time","Reference2_time_icon","WaterSortEnergyCanvas1080x1920"]:
  var item=game.get_node_or_null(key)
  if is_instance_valid(item):dock(item,Vector2(available.position.x,top.y) if key=="WaterSortEnergyCanvas1080x1920" else top)
 if game.buttons.has("Pause"):dock(game.buttons.Pause,Vector2(available.end.x-DESIGN.x,top.y))
 for key in ["Undo","RefreshColors","Restart"]:
  if game.buttons.has(key):dock(game.buttons[key],bottom)

static func policy(view:CanvasItem):
 return view.get_viewport().get_meta("screen_layout",null) if view.is_inside_tree() else null

static func dock(item:Control,offset:Vector2)->void:
 if not item.has_meta("screen_base_position"):item.set_meta("screen_base_position",item.position)
 item.position=Vector2(item.get_meta("screen_base_position"))+offset

static func fit_menu(menu:Control,board:Control,reference:Vector2)->bool:
 var p=policy(menu)
 if p==null:return false
 var available:Rect2=menu.get_global_transform_with_canvas().affine_inverse()*p.safe_rect
 var k:=minf(available.size.x/reference.x,available.size.y/reference.y)
 board.scale=Vector2.ONE*k;board.position=available.position
 board.size=available.size/k
 var extra:=board.size-reference
 var home_group:Dictionary={}
 var brand=board.get_node_or_null("HomeBrandCandidate")
 if menu.page=="home" and is_instance_valid(brand):
  # Grow toward the approved915-wide registration only when spare height
  # permits. Treat title/frame and the existing button block as one group:
  # extra height must not accumulate between the hero and Start.
  if not brand.has_meta("screen_brand_scale"):brand.set_meta("screen_brand_scale",brand.scale.x)
  var old_scale:float=brand.get_meta("screen_brand_scale")
  var top:float=brand.geometry.title.source_rect[1]
  var bottom:float=brand.geometry.frame.source_rect[3]
  var span:=bottom-top
  var new_scale:=minf(board.size.x/float(brand.geometry.reference_canvas[0]),old_scale+maxf(0,extra.y)/span)
  var growth:float=(new_scale-old_scale)*span
  home_group={"scale":new_scale,"brand_y":(extra.y-growth)*.5-top*(new_scale-old_scale),"buttons_y":(extra.y+growth)*.5}
 for child in board.get_children():
  if not child is Control:continue
  if child.name=="Reference2Background":child.hide();continue
  var anchor:String=child.get_meta("screen_anchor","center")
  var id:=str(child.name)
  if id in ["Reference2EnergyHeader","MenuBackBase","MenuBackArrow","back","home_settings","NewHome_settings"]:anchor="top"
  if id in ["home_start","home_levels","home_ranking","HomeCurrentLevel","continue","previous","next","PreviousPageArt","NextPageArt"] or id.begins_with("NewHome_main_") or id.begins_with("NewHome_levels_") or id.begins_with("NewHome_game_records_"):anchor="bottom"
  var offset:=Vector2(extra.x*.5,extra.y*(0.0 if anchor=="top" else (1.0 if anchor=="bottom" else .5)))
  if id=="Reference2EnergyHeader":offset.x=0
  if id in ["MenuBackBase","MenuBackArrow","back","home_settings","NewHome_settings"]:offset.x=extra.x
  if not home_group.is_empty():
   if anchor=="bottom":offset.y=home_group.buttons_y
   if child==brand:
    if not child.has_meta("screen_base_position"):child.set_meta("screen_base_position",child.position)
    child.scale=Vector2.ONE*float(home_group.scale)
    offset.x=(board.size.x-float(brand.geometry.reference_canvas[0])*child.scale.x)*.5-Vector2(child.get_meta("screen_base_position")).x
    offset.y=home_group.brand_y
  # Compact safe height438..479: preserve all20 cells and44px hits. Reflow
  # the authored grid/pager group, never shrink buttons or intercept events.
  if menu.page=="levels" and (menu.get_window().get_final_transform()*p.safe_rect).size.y<480.0:
   for prefix in ["LevelTile","LevelState","level_number_","level_"]:
    if id.begins_with(prefix) and id.trim_prefix(prefix).is_valid_int():offset.y-=8.0*floori(float(int(id.trim_prefix(prefix))%20)/4.0)
   if id in ["previous","next","PreviousPageArt","NextPageArt"]:offset.y-=14.0
  dock(child,offset)
 if menu.page=="levels" and menu.buttons.has("continue"):
  # Preserve the original native Button and44.1 window-unit target. Its old
  # pager clearance offset must yield to the actual safe bottom on short screens.
  var button:Button=menu.buttons["continue"]
  button.set_meta("touch_local_offset",Vector2(0,14))
  var local_safe:Rect2=button.get_global_transform_with_canvas().affine_inverse()*p.safe_rect
  var hit:Rect2=button.effective_hit_rect()
  var correction:=Vector2(maxf(0,local_safe.position.x-hit.position.x)+minf(0,local_safe.end.x-hit.end.x),maxf(0,local_safe.position.y-hit.position.y)+minf(0,local_safe.end.y-hit.end.y))
  button.set_meta("touch_local_offset",Vector2(0,14)+correction)
  var next_top:float=(button.get_global_transform_with_canvas()*button.effective_hit_rect()).position.y
  var separation:=.25/menu.get_window().get_final_transform().y.length()
  for key in ["previous","next"]:
   if not menu.buttons.has(key):continue
   var pager:Button=menu.buttons[key]
   pager.set_meta("touch_local_offset",Vector2.ZERO)
   var pager_tx:Transform2D=pager.get_global_transform_with_canvas()
   var pager_hit:Rect2=pager_tx*pager.effective_hit_rect()
   var shift:=minf(0,next_top-separation-pager_hit.end.y)
   pager.set_meta("touch_local_offset",Vector2(0,shift/pager_tx.y.length()))
 if is_instance_valid(menu.modal) and menu.modal.get_parent()==menu:
  if menu.modal.has_method("_fit"):menu.modal._fit()
  else:fit_legacy_modal(menu.modal,reference)
 return true

static func row_stride(canvas:Control,art_height:float,authored_gap:float)->float:
 if policy(canvas)==null:return art_height+authored_gap
 var tx:=canvas.get_window().get_final_transform()*canvas.get_global_transform_with_canvas()
 return maxf(art_height+authored_gap,46.1/maxf(.0001,tx.y.length()))

static func fit_modal(view:Control,canvas:Control,reference:Vector2,shade:Control=null)->bool:
 var p=policy(view)
 if p==null:return false
 if view.get_meta("screen_fitting",false):return true
 view.set_meta("screen_fitting",true)
 var parent_tx:Transform2D=view.get_parent().get_global_transform_with_canvas() if view.get_parent() is CanvasItem else view.get_canvas_transform()
 var frame:Rect2=parent_tx.affine_inverse()*p.window_rect
 view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 view.position=frame.position;view.size=frame.size
 var available:Rect2=view.get_global_transform_with_canvas().affine_inverse()*p.safe_rect
 var k:=minf(available.size.x/reference.x,available.size.y/reference.y)
 canvas.scale=Vector2.ONE*k;canvas.position=available.get_center()-reference*k*.5
 if is_instance_valid(shade):shade.position=Vector2.ZERO;shade.size=view.size
 view.set_meta("screen_fitting",false)
 return true

static func fit_legacy_modal(view:Control,reference:Vector2)->void:
 var p=policy(view)
 if p==null:return
 var parent_tx:Transform2D=view.get_parent().get_global_transform_with_canvas()
 var available:Rect2=parent_tx.affine_inverse()*p.safe_rect
 var k:=minf(available.size.x/reference.x,available.size.y/reference.y)
 view.scale=Vector2.ONE*k;view.position=available.get_center()-reference*k*.5
 # Legacy menu modal has a dimmer child and fixed authored content. Extend the
 # blocker/dimmer to the complete window, without changing its content positions.
 if view.get_child_count()>0 and view.get_child(0) is ColorRect:
  var dim:ColorRect=view.get_child(0)
  var full:Rect2=view.get_global_transform_with_canvas().affine_inverse()*p.window_rect
  dim.position=full.position;dim.size=full.size
