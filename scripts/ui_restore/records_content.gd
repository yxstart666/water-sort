extends RefCounted
static func for_locale(locale:String)->Dictionary:
	if locale=="zh":
		return {"title":"游戏记录","summary":"汇总","global":"全球排行榜","cleared":"已通关","moves":"总步数","time":"总用时","section":"关卡记录","columns":["关卡","步数","用时"],"empty":"还没有通关记录。\n完成一关后会显示在这里。","local":"本机最佳记录 · 步数与用时来自同一局","global_title":"全球排行暂不可用","unavailable":"全球排行服务尚未接入。\n当前没有可显示的全球记录。","level":"第 %d 关","back":"返回"}
	return {"title":"Game Records","summary":"Summary","global":"Global Leaderboard","cleared":"Cleared","moves":"Moves","time":"Time","section":"Level Records","columns":["Level","Moves","Time"],"empty":"No completed levels yet.\nFinish a level to see its record here.","local":"Local best runs · Moves and time stay paired","global_title":"Leaderboard unavailable","unavailable":"Global rankings are not connected.\nNo global records are available.","level":"Level %d","back":"Back"}
