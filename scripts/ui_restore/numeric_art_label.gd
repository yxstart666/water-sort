extends Control
## Presentation-only glyph label. No state, counters, economics or hit targets.
## Approved production families use independent PNGs; generic regions remain supported.
signal coverage_changed(complete:bool)
static var approved_families:Dictionary={}
var text:String="":
	set(value):
		if text==value:return
		text=value;_invalidate()
var content_rect:=Rect2():
	set(value):
		if content_rect==value:return
		content_rect=value;_invalidate()
var minimum_scale:=0.0:
	set(value):minimum_scale=maxf(0,value);_invalidate()
var maximum_scale:=INF:
	set(value):maximum_scale=value;_invalidate()
var glyphs:Dictionary={}
var kerning:Dictionary={}
var default_gap:=0.0
var errors:Array[String]=[]
var _layout:Dictionary={}
var _complete:=false
var _dirty:=true
func _init()->void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _ready()->void:
	resized.connect(_invalidate);_invalidate()
func configure(spec:Dictionary,textures:Dictionary)->bool:
	# Source region and ink bbox share atlas pixel units. Ink bbox is local
	# to its region; bearing is the region's top-left relative to baseline.
	glyphs={};kerning=spec.get("kerning_px",{}).duplicate();errors.clear();default_gap=0
	minimum_scale=float(spec.get("minimum_scale",0));maximum_scale=float(spec.get("maximum_scale",INF))
	for character in spec.get("glyphs",{}):
		var source:Dictionary=spec.glyphs[character]
		var texture:Texture2D=textures.get(str(source.get("texture","")))
		if texture==null:errors.append("Missing texture for "+str(character));continue
		var region:=_rect(source.get("region_px",[0,0,texture.get_width(),texture.get_height()]))
		var ink:=_rect(source.get("ink_bbox_px",[0,0,region.size.x,region.size.y]))
		var bearing_values:Array=source.get("bearing_px",[0,0])
		var advance:=float(source.get("advance_px",ink.end.x))
		if not region.has_area() or not ink.has_area() or not Rect2(Vector2.ZERO,texture.get_size()).encloses(region) or not Rect2(Vector2.ZERO,region.size).encloses(ink) or advance<=0:
			errors.append("Invalid measured glyph bounds for "+str(character));continue
		glyphs[str(character)]={"texture":texture,"region":region,"ink":ink,"bearing":Vector2(bearing_values[0],bearing_values[1]),"advance":advance}
	_invalidate();return errors.is_empty()
func configure_family(family:String,face_pixels:float)->bool:
	if approved_families.has(family):
		var cached:Dictionary=approved_families[family];glyphs=cached.glyphs;kerning=cached.kerning;default_gap=cached.default_gap;errors.clear()
		minimum_scale=face_pixels/100;maximum_scale=minimum_scale;set_meta("approved_numeric_family",family);set_meta("numeric_face_px",face_pixels);_invalidate();return true
	var folder:="res://art/colorpause/ui_unified_20261030/numerals/"
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"manifest.json"))
	glyphs={};errors.clear();kerning={};default_gap=0
	if not manifest.families.has(family):push_error("Missing approved numeral family: "+family);return false
	var spec:Dictionary=manifest.families[family]
	default_gap=float(spec.get("default_gap_em",0))*100
	for pair in spec.get("pair_kerning_em",{}):kerning[pair]=float(spec.pair_kerning_em[pair])*100
	for character in spec.glyphs:
		var item:Dictionary=spec.glyphs[character];var texture:Texture2D=load(folder+str(item.file))
		if texture==null:errors.append("Missing approved glyph "+str(character));continue
		var ink:=Rect2(texture.get_image().get_used_rect())
		glyphs[character]={"texture":texture,"region":Rect2(Vector2.ZERO,texture.get_size()),"ink":ink,"bearing":Vector2(0,float(item.offset_y_em)*100),"advance":float(item.advance_em)*100,"unit_scale":100.0/float(item.native_numeric_em)}
	if errors.is_empty():approved_families[family]={"glyphs":glyphs.duplicate(),"kerning":kerning.duplicate(),"default_gap":default_gap}
	minimum_scale=face_pixels/100;maximum_scale=minimum_scale
	set_meta("approved_numeric_family",family);set_meta("numeric_face_px",face_pixels);_invalidate();return errors.is_empty()
static func _rect(values:Array)->Rect2:
	return Rect2(values[0],values[1],values[2],values[3])
func _invalidate()->void:
	_dirty=true;queue_redraw()
func is_complete()->bool:
	_resolve();return _complete
func metrics()->Dictionary:
	_resolve()
	var result:=_layout.duplicate(true)
	result.erase("draws");result.errors=errors.duplicate();return result
func _resolve()->void:
	if not _dirty:return
	_dirty=false
	var draws:Array=[];var bounds:=Rect2();var cursor:=0.0;var previous:=""
	var complete:=not text.is_empty() and errors.is_empty()
	for i in text.length():
		var character:=text.substr(i,1)
		if not glyphs.has(character):complete=false;break
		var glyph:Dictionary=glyphs[character]
		if not previous.is_empty():cursor+=float(kerning.get(previous+character,default_gap))
		var ink:Rect2=glyph.ink
		var unit:float=glyph.get("unit_scale",1.0)
		var target:=Rect2(Vector2(cursor,0)+Vector2(glyph.bearing)+ink.position*unit,ink.size*unit)
		bounds=bounds.merge(target) if not draws.is_empty() else target
		draws.append({"character":character,"texture":glyph.texture,"source":Rect2(Vector2(glyph.region.position)+ink.position,ink.size),"target":target})
		cursor+=float(glyph.advance);previous=character
	var available:=content_rect if content_rect.has_area() else Rect2(Vector2.ZERO,size)
	var factor:=0.0;var origin:=Vector2.ZERO
	if complete and bounds.has_area() and available.has_area():
		factor=minf(maximum_scale,minf(available.size.x/bounds.size.x,available.size.y/bounds.size.y))
		complete=factor>=minimum_scale and factor>0
		origin=available.get_center()-bounds.get_center()*factor
	else:complete=false
	var ink_rect:=Rect2(origin+bounds.position*factor,bounds.size*factor)
	var glyph_rects:Array=[]
	for item in draws:
		item.target=Rect2(origin+item.target.position*factor,item.target.size*factor)
		glyph_rects.append({"character":item.character,"ink_rect":item.target})
	_layout={"text":text,"complete":complete,"source_ink_bounds":bounds,"ink_rect":ink_rect,"advance_px":cursor,"scale":factor,"glyphs":glyph_rects,"draws":draws}
	if complete!=_complete:
		_complete=complete;coverage_changed.emit(complete)
func _draw()->void:
	_resolve()
	if not _complete:return
	for item in _layout.draws:draw_texture_rect_region(item.texture,item.target,item.source)
