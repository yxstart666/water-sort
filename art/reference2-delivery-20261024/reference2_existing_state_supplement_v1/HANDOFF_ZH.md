# 已实现生产状态静态补充

仅新增本包。读取 reference2_production_state_binding_v1 的原32+24源码核对证据；不改旧freeze、游戏或本地GUI，不增加业务，不上传。

## 三组双语布局

- layouts/mask_intro_{zh,en}.json：L3本实例首次load_level(2)进入，Start恢复；mask_intro_seen非持久。明确下层颜色隐藏、顶部仍按既有规则倾倒，隐藏颜色不是整瓶锁。不加取消、首页、连续教学或新锁规则。隐藏阈值只读真实配置，QA底图只是装配占位，未伪造L3下层遮罩效果。
- layouts/bonus_bottle_{zh,en}.json：第2关起未领辅助瓶，或现有无步救援入口；每局一次local_trial。确认“增加空瓶”，取消零奖励。表现忙时不得打开。
- layouts/bonus_slot_{zh,en}.json：第2关起第四订单位+入口，每局一次独立local_trial；确认“增加订单位”。资格不与辅助瓶共用。扩槽可触发现有等待成品收件队列，UI不得重复收件或发奖。

无广告SDK、视频图标、播放页、假广告奖励或体力扣费。奖励取消/失败/重复/过期不是新增页面，REWARD_TERMINAL_STATE_BINDING.json 将其绑定已有两个确认弹窗及既有收起/提示行为，不发奖、不发明重试按钮。默认只local_trial/cancel。

## 精确布局和状态

画布940×1672；面板100,470,740,778，按钮高132，双按钮144/496，单Start居中。字体统一reference2_sc_font_v1 SC OTF。所有文字是动态字体，不烘焙。原蓝金按钮母版48px九宫格复用，不新增运行PNG。

360宽按钮高度50.55dp，全部触区不重叠；按钮下缘至面板外底82px，保守扣48px内带后仍34px。normal/focus/pressed/disabled/processing在各按钮states给出整底亮度及是否输入；资格始终取生产逻辑，不能把视觉normal当可领取。提交中两按钮不可再次点，点击前校验attempt/request/type/已领/忙状态。

生产orders_v3坐标1080×1920，需要按实际safe-area、现有控件挂点适配；这里不是可直接运行scene。L3实际遮罩用生产已有渲染与阈值，不拿L4锁图覆盖。

## QA和边界

qa/ 每布局含940和360画面，共12张；contact_sheet.png六态总览。35项文字边界通过，qa/geometry_validation.json六态资源/触区/留白检查通过；已实际查看总览。背景是原中文组件装配占位，不是对应真实level或英语实机。真实进出、资格、撤销、取消/过期/重复、等待成品收件仍需owner验证。

所有资源路径从交付包/工作区根解析。RUNTIME_SOURCE_ALLOWLIST只有母板和SC字体。FREEZE.sha256覆盖本包，不触碰既有冻结目录。
