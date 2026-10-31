extends RefCounted
## Verified, explicit runtime faces. Unknown system fallback is never enabled.
const DEFINITIONS: Dictionary={
 "sc":{"path":"res://art/reference2-delivery-20261024/reference2_sc_font_v1/fonts/NotoSansCJKsc-Bold.otf","sha":"0b73a1dc8ff56140320179d71e5ab4563a216555e18dcde2e98b475d1293cdec"},
 "latin":{"path":"res://art/reference2-delivery-20261024/reference2_dependency_errata_v1/fonts/NotoSans-Bold.ttf","sha":"e83493c945848ecd4a9ad0f6d19164541a0d3e23a9c952304a00a46e00272ac5"},
 "lxgw":{"path":"res://assets/colorpause_ui_20261030/fonts/LXGW975YuanSC-700W.ttf","sha":"f392de4cba941f3c44c7770cfed7ac3c658b46b7e3a4b2546fe155010109d403"}
}
static var cache: Dictionary={}
static var errors: Array[String]=[]
static func load_verified(path: String, expected_sha: String) -> FontFile:
 # Export remaps the authored font path to an imported FontFile; raw TTF/OTF
 # source bytes are deliberately absent from a normal exported pack.
 if not ResourceLoader.exists(path,"FontFile"):
  errors.append("Font resource missing: "+path);push_error(errors.back());return null
 var imported=ResourceLoader.load(path,"FontFile")
 if not imported is FontFile:
  errors.append("Invalid font resource: "+path);push_error(errors.back());return null
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(imported.data)
 if imported.data.is_empty() or hash.finish().hex_encode()!=expected_sha:
  errors.append("Font identity mismatch: "+path);push_error(errors.back());return null
 var font:FontFile=imported.duplicate()
 font.allow_system_fallback=false;font.fallbacks=[]
 font.multichannel_signed_distance_field=true
 font.msdf_pixel_range=16
 font.msdf_size=128
 return font
static func get_font(id: String) -> FontFile:
 if cache.has(id):return cache[id]
 var font:=FontFile.new();font.allow_system_fallback=false;font.fallbacks=[]
 # Runtime labels are authored in both 320dp and 1080px spaces. A distance
 # field preserves the original face at the user's large window scale.
 font.multichannel_signed_distance_field=true
 font.msdf_pixel_range=16
 font.msdf_size=128
 if not DEFINITIONS.has(id):
  errors.append("Unknown font binding: "+id);push_error(errors.back());cache[id]=font;return font
 var item:Dictionary=DEFINITIONS[id];var path:String=item.path
 var verified:=load_verified(path,item.sha)
 if verified==null:cache[id]=font;return font
 font=verified;cache[id]=font
 if id=="latin":font.fallbacks=[get_font("sc")]
 return font
