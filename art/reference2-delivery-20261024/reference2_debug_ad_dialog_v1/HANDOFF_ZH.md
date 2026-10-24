# 测试广告弹窗静态布局

用户授权的调试测试功能，仅本独立包新增。无真实广告播放/SDK接入声明，无运行奖励逻辑，不改旧冻结目录，不上传。

layouts/debug_ad_zh.json、debug_ad_en.json 两份布局，标题“测试广告/Test Ad”，正文“仅用于开发测试/Development testing only”。按钮“不看，退出/Cancel”和“已看完/Completed”。动态请求标签分别为额外空瓶、订单位、恢复体力；内部request id不向玩家展示。

仅debug构建+显式测试开关同时开启。release必须隐藏且拒绝mock完成成功，不能只是藏入口。测试弹窗只回传cancelled/completed与原request id，既有业务handler校验后处理；弹窗本身不发奖。Close/Escape同cancel，重复/过期/取消后回调不发奖。详见ROUTE_CONTRACT.json。

复用原图2蓝金母板48px九宫格及SC字体，零新运行PNG。940×1672画布；面板100,500,740,718；按钮144/496,1010,300,132。360宽按钮50.55dp、间隔52设计px；底部外缘留白76px，扣48px保守内边带后仍28px。安全区与实际生产1080坐标由owner适配，不声称可直接导入scene。

两语言各三个动态请求标签均有940/360 QA，共12张；qa/contact_sheet.png总览。30项文字边界通过，资源路径及触区不重叠检查通过，已实际查看总览。底图是中文静态占位，不是实机截图或广告播放证据。所有测试返回、release拦截和奖励次数仍需真实接入验收。

资源路径从工作区/包根解析。RUNTIME_SOURCE_ALLOWLIST.txt只列原母版和SC字体；FREEZE.sha256只冻结本包。
