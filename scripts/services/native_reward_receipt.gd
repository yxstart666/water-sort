extends RefCounted
## Client-local SDK receipt identity, not server-side verification or anti-tamper.
const SOURCE:="google_test_sdk"
const PLACEMENTS:=["bottle","slot","energy","shuffle","undo"]
static func valid(value:Variant)->bool:
	if not value is Dictionary:return false
	for key in ["request_id","attempt_id","context_id","placement","source","outcome","reason"]:
		if not value.get(key) is String or value[key].is_empty():return false
	return value.source==SOURCE and value.request_id.begins_with("google_test:") and value.placement in PLACEMENTS and value.get("outcome")=="completed" and value.get("reason")=="verified_test_sdk"
static func identity(value:Dictionary)->Dictionary:
	var result:Dictionary={}
	for key in ["request_id","attempt_id","context_id","placement","source","outcome","reason"]:result[key]=value.get(key)
	return result
static func same(a:Variant,b:Variant)->bool:
	# JSON restores integral numbers as doubles. Normalize both operands, while
	# retaining booleans, arrays, keys and exact string/color identities.
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
