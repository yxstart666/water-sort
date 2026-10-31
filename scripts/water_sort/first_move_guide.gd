extends RefCounted
## Shared display/input binding. Metadata names logical initial slots, never pixels.
const LEGACY_BOTTLES=[["blue","green","blue"],["green","blue","blue"],["green","green"],["red"],["red","red","red"]]
var _rules_id:=0
var _nodes:Array=[]
var _ids:Array=[]
func target(game)->int:
 if game.level_index!=0 or game.moves>0 or game.rules==null:return -1
 var nodes:Array=game.bottle_nodes.map(func(n):return n.get_instance_id())
 if _rules_id!=game.rules.get_instance_id() or _nodes!=nodes:
  _rules_id=game.rules.get_instance_id();_nodes=nodes;_ids.clear()
  var pair:Variant=game.rules.level.get("first_move_guide",{})
  if not game.rules.level.has("first_move_guide") and game.rules.level.bottles==LEGACY_BOTTLES:pair={"source":3,"target":4}
  if not pair is Dictionary:return -1
  for key in ["source","target"]:
   var v:Variant=pair.get(key,-1)
   if not (v is int or v is float) or not is_finite(float(v)) or floorf(float(v))!=float(v) or v<0 or v>=nodes.size():return -1
  var source:=int(pair.source);var destination:=int(pair.target)
  if source==destination or not game.rules.can_pour(source,destination):return -1
  _ids=[nodes[source],nodes[destination]]
 if _ids.size()!=2:return -1
 var source:=nodes.find(_ids[0]);var destination:=nodes.find(_ids[1])
 if source<0 or destination<0 or not game.rules.can_pour(source,destination):return -1
 if game.selected>=0 and game.selected!=source:return -1
 return source if game.selected<0 else destination
