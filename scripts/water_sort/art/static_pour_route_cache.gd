extends RefCounted
## Immutable static geometry proofs only. Never cache moving-peer admission,
## rewards, node references, temporal samples or a failed route.
const LIMIT:=64
static var values:Dictionary={}
static var order:Array=[]
static var rejected:Dictionary={}
static var rejected_order:Array=[]
static func key(parts:Array)->String:
 return var_to_bytes(parts).hex_encode().sha256_text()
static func fetch(id:String)->Dictionary:
 if not values.has(id):return {}
 order.erase(id);order.append(id);return values[id].duplicate(true)
static func put(id:String,candidate:Dictionary)->void:
 values[id]=candidate.duplicate(true);order.erase(id);order.append(id)
 while order.size()>LIMIT:values.erase(order.pop_front())
static func was_rejected(id:String)->bool:return rejected.has(id)
static func reject(id:String)->void:
 rejected[id]=true;rejected_order.erase(id);rejected_order.append(id)
 while rejected_order.size()>LIMIT:rejected.erase(rejected_order.pop_front())
