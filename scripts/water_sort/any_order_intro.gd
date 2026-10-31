extends RefCounted
## Content adapter for the existing mechanism modal; no rule or save mutations.
const ID:="any_order_lock_v1"
static func pending(rules,locale:String,seen:Callable)->Dictionary:
 if not seen.is_valid() or seen.call(ID):return {}
 for mask in rules.level.get("masks",[]):
  var condition:Dictionary=rules.condition_progress(mask)
  if condition.kind!="any" or int(condition.required)<2 or int(condition.remaining)<=0:continue
  var layers:Array=rules.bottles[int(mask.bottle)].duplicate()
  var steps:Array=[]
  for n in range(int(condition.required),-1,-1):steps.append(str(n))
  var sequence:=" → ".join(steps)
  var text:="任意完成 %d 笔订单即可揭布。\n剩余数量：%s。\n归零前不能向这个瓶子倒入或倒出。" % [condition.required,sequence] if locale=="zh" else "Complete any %d orders to unlock.\nRemaining: %s.\nLocked bottles cannot receive or pour." % [condition.required,sequence]
  var illustration:=func():
   var art=preload("res://scripts/water_sort/cover_intro_art.gd").new()
   art.condition=condition.duplicate();art.locale=locale;art.covered_demo_layers=layers.duplicate();return art
  return {"id":ID,"body":text,"illustration":illustration}
 return {}
