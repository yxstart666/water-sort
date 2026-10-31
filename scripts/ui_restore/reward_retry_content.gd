extends RefCounted
## Copy for the verified development-ad earned-receipt save-retry route.
## Rendering recipes contain sampleOnly text; this host copy is separate.
static func for_locale(locale: String) -> Dictionary:
	if locale == "zh":
		return {"title":"保存奖励", "body":"奖励未保存，请重试保存。\n无需再次观看测试广告。", "retry":"重试保存", "dismiss":"返回"}
	return {"title":"Saving Reward", "body":"Reward was not saved. Retry saving.\nNo new test ad is required.", "retry":"Retry saving", "dismiss":"Back"}
