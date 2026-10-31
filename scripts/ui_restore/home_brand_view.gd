extends Control
## Candidate bitmap title/frame in one original915x1719 registration space.
## No routes or progress values. The host owns the available slot and buttons.
const TITLE="res://assets/colorpause_ui_20261030/home_transparent_candidate/home_title.png"
const FRAME="res://assets/colorpause_ui_20261030/home_transparent_candidate/home_hero_frame.png"
const HERO="res://assets/colorpause_ui_20261030/home/ColorPause_GooglePlay_Icon_512.png"
const GEOMETRY="res://assets/colorpause_ui_20261030/home_transparent_candidate/geometry.json"
const CLIP=preload("res://scripts/ui_restore/home_hero_round_clip.gdshader")
const HOST_K:=0.39
const HOST_ORIGIN_DP:=Vector2((390.0-915.0*HOST_K)*0.5,432.0-1085.0*HOST_K)
var geometry:Dictionary
var title:TextureRect
var frame:TextureRect
var hero:TextureRect
func _ready()->void:
 name="HomeBrandCandidate";mouse_filter=Control.MOUSE_FILTER_IGNORE
 geometry=JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY))
 size=Vector2(915,1719)
 var host_factor:=940.0/390.0
 position=HOST_ORIGIN_DP*host_factor;scale=Vector2.ONE*HOST_K*host_factor
 hero=_image("HomeHeroApproved512",HERO,_box(geometry.hero.qa_underlay_rect))
 # Quad UV stays0..1; shader performs uniform center cover and rounded clipping.
 hero.stretch_mode=TextureRect.STRETCH_SCALE
 var clip:=ShaderMaterial.new();clip.shader=CLIP
 clip.set_shader_parameter("clip_size",hero.size);clip.set_shader_parameter("corner_radius",float(geometry.hero.qa_corner_radius));hero.material=clip
 # The user removed the outer blue frame. Keep its registration in geometry
 # so responsive title/hero/button spacing stays stable without drawing it.
 frame=_image("HomeHeroFrameCandidate",FRAME,_box(geometry.frame.source_rect))
 frame.hide()
 title=_image("HomeTitleCandidate",TITLE,_box(geometry.title.source_rect))
func _box(rect:Array)->Rect2:
 return Rect2(rect[0],rect[1],rect[2]-rect[0],rect[3]-rect[1])
func _image(id:String,path:String,box:Rect2)->TextureRect:
 var image:=TextureRect.new();image.name=id;image.texture=load(path)
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 image.position=box.position;image.size=box.size;add_child(image);return image
