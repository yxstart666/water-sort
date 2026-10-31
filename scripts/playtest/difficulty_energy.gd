extends RefCounted
## Explicit difficulty-testing exemption, never an ad reward/provider.
var entered:Dictionary={}
var completed:Dictionary={}
func snapshot()->Dictionary:
	return {"ok":true,"energy":30,"cap":30,"next_recovery_seconds":null,"ad_available":false,"error":"","difficulty_test_exempt":true}
func result(id:String,duplicate:bool)->Dictionary:
	return {"accepted":not id.is_empty(),"duplicate":duplicate,"energy":30,"delta":0,"receipt":{"kind":"difficulty_test_exemption","attempt_id":id,"delta":0,"test_only":true},"events":[]}
func enter_attempt(id:String)->Dictionary:
	var duplicate:=entered.has(id)
	if not id.is_empty():entered[id]=true
	return result(id,duplicate)
func complete_attempt(id:String)->Dictionary:
	var duplicate:=completed.has(id)
	if not id.is_empty():completed[id]=true
	return result(id,duplicate)
func is_ad_available()->bool:return false
func commit_development_refill(_id:String,_authority)->Dictionary:
	return {"accepted":false,"reason":"energy_full","delta":0,"energy":30,"events":[],"receipt":{}}
