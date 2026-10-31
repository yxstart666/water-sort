extends RefCounted
## Presentation data only. Eligibility, balances and callbacks remain host-owned.
## The new approved energy design can consume these slots without changing rules.
static func present(snapshot:Dictionary,locale:String,ad_action_available:bool,notice:="")->Dictionary:
	var value:Variant=snapshot.get("current","--")
	var readable:bool=(value is int or value is float) and bool(snapshot.get("ok",true))
	var full:bool=readable and value>=snapshot.get("capacity",30)
	var state:="unavailable" if not readable else ("full" if full else ("insufficient" if value<5 else "recovering"))
	var headings:Dictionary={"unavailable":["体力不可用","Energy unavailable"],"full":["体力已满","Energy full"],"insufficient":["体力不足","Not enough energy"],"recovering":["体力补给","Restore energy"]}
	# A full balance legitimately has no next recovery time (null).
	var recovery:Variant=snapshot.get("next_recovery_seconds",0)
	var seconds:=int(recovery) if recovery is int or recovery is float else 0
	var cap:Variant=snapshot.get("capacity",30)
	var ratio:float=clampf(float(value)/float(cap),0,1) if readable and (cap is int or cap is float) and cap>0 else 0.0
	var lang:=0 if locale=="zh" else 1
	return {"current":value,"cap":cap,"readable":readable,"ratio":ratio,"state":state,"heading":headings[state][lang],"capacity":"%s / %s" % [value,snapshot.get("capacity",30)],"rule":("每 2 分钟恢复 1 点体力" if lang==0 else "Recover 1 energy every 2 minutes") if readable else ("暂时无法读取体力，请稍后再试。" if lang==0 else "Energy could not be read. Try again later."),"recovery_time":"%02d:%02d" % [seconds/60,seconds%60] if readable and not full else "","ad_action_available":ad_action_available,"ad_caption":("重试保存" if lang==0 else "Retry saving") if snapshot.get("ad_retry_available",false) else ("看广告补满" if lang==0 else "Refill with ad"),"close_caption":"返回" if lang==0 else "Back","notice":notice}
