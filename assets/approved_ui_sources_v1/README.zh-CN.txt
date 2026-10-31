彩瓶UI完整原组件工程补充包 v1 — 2026-10-30
目的：补齐当前6a+d88固定候选未包含的完整normal原件与真实选关原稿，让接线owner直接使用整体素材，不再把小icon、字、底重新猜位拼装。本包不是工程覆盖包，不含源码补丁、不含任何用户存档/SDK/密钥。全部9张PNG均原字节复制，无重绘、裁剪、清alpha、转码或缩放。

一、允许项与状态（仅此清单）
1 assets/full_buttons/button_levels_zh_normal.png：245×242，完整“关卡”按钮。
2 assets/full_buttons/button_records_zh_normal.png：243×242，完整“记录”按钮。主页按钮按这份原件显示“记录”；进入后的页面标题仍为“游戏记录”，功能路由不变，不把页面标题改短。
3 assets/full_buttons/button_settings_zh_normal.png：138×139，原完整蓝圆白齿轮。用作同造型与可见主体注册基准。当前候选已存在逐像素相同的 res://assets/colorpause_ui_20261030/home/button_settings_zh_normal.webp。
4 assets/full_buttons/button_home_reference.png：282×247，固定中文“主页”的完整底+icon+字。
5 assets/full_buttons/button_replay_reference.png：283×247，固定中文“重玩”的完整底+icon+字。
6 references/levels_reference_914x1720.png：真实原稿，实际914×1720，原文件exec-d476e3fe-2bec-47c8-ae7b-6dc84b4a33b2.png，SHA822e6e30012bf0bcad8f287ba8418afe369f5c80a522515c50fcaf65898c5d32。不是915宽；不要套主页915×1719坐标。
7 references/start_source_reference.png：695×255不透明RGB参考，仅作Start整体原造型、动态第n关墨迹/描边/基线基准，不作含固定第4关的运行全图。
8 assets/home/label_start_zh-CN.png：468×129原“开始游戏”透明固定艺术字。
9 assets/highres/settings_v1_raw.png：1254×1254，root本次明确允许的同风格高清settings修复源。它是新高分重建，不是原小图的逐像素无损放大；接入后实际画面仍需验。保留原PNG全部alpha，按可见主体而不是画布占比映射。

不含、不许可混入：help_v4及其他help候选、玩法说明flat_v1、settings_v2、source_review_pack内任何blocked/unapproved修复素材。本包不更改问号；其精准重制仍待完成。不得因为本包名字有“SourceSupplement”就从审查包批量补入其他图。

二、完整组件接线（不改业务）
Home关卡：以完整button_levels替代NewHome_levels_base/icon/label三层显示，保留原home_levels Button事件、触区与44px下限；移除/隐藏旧三层，避免叠字。自然比例245/242，按整体可见ink注册，不作九宫格或横纵不等比拉伸。
Home记录：同理整体button_records替代NewHome_game_records_*三层；保持原home_ranking/记录路由和页面标题“游戏记录”。本次明确使用按钮原件“记录”，不再追加四字label覆盖原字。
Home settings：原小图作注册基准，新settings_v1按第三节受控替换。保留蓝圆白齿轮设计，不换白金方底的其他hires。原home_settings事件不变。
Pause/Victory主页与重玩：完整button_home_reference/button_replay_reference替代对应底+icon+固定字的组合显示；保留原按钮事件/保存确认/忙时合同。它们是带固定中文的完整normal，不是可编辑空底；英文不得拿中文图充当英文，也不要把固定字九宫格拉伸。英文完整源另审，不因此拦中文候选。
Start：使用label_start原固定艺术字保持自然比例；动态第n关独立保留真实进度与值。原RGB start参考有星空背景和固定“第4关”，严禁整图盖到按钮或伪造当前关数。

三、坐标、可见主体与高清settings映射
所有准确源坐标/原始source SHA/组件框见ORIGINAL_COORDINATES_AND_BINDING.json；XYXY右/下不含。已逐RGB核对完整按钮、start源切片与对应原始915×1719画布，无一个像素被重绘。
Home来源：exec-0ffb0725-45cc-4072-9a79-40161fc77975.png，915×1719：
  settings [37,44,175,183]；levels [77,1356,322,1598]；records [336,1356,579,1598]；start文字 [229,1125,697,1254]；start参考 [111,1085,806,1340]。
Pause控件来源：exec-757b23d8-1f24-410f-a15e-e9e79f0b0aa9.png，915×1719：
  home [156,1351,438,1598]；replay [476,1351,759,1598]。
这些是原稿取材坐标，不要求恢复原三按钮主页布局；当前两个入口和去Home外框的用户决策保持。
高清settings1254²的稳定主体(alpha>127)bbox [43,52,1207,1207]，中心[625,629.5]；零星低alpha可延伸到画布边缘，不拿它们当主体锚点。
原138×139小图稳定可见bbox [5,6,130,129]。给定旧按钮当前物理可见目标框T：
  k=min(T.width/1164,T.height/1155)
  新整画布绘制尺寸=(1254*k,1254*k)
  新整画布左上=T.center-k*(625,629.5)
保持等比；不要简单把1254画布fit到旧138×139节点框，否则主体占比漂移。完整公式和旧138×139局部框的数值例子在JSON里。读取原alpha，不重新去毛边、不改变图形比例或高光。

四、选关页必须按真原稿复原，不是仅3×4
完整参考914×1720已确认包含3列×4行、宽当前关卡胶囊、所有格子都在白板内、底部提示与翻页组。它是参考图，不是整屏运行贴图：第4关、完成1/2/3、锁5..12、1/5及“布局示例”均为示例数据，必须由真实model/current/allowed/completed/page_count重建，不伪通关、不解锁用户存档。
以914×1720作为统一注册坐标空间，k=min(safe_width/914,safe_height/1720)，整组等比居中；保持板/卡/胶囊关系后再做必要安全区约束。不要把别页194×93的summary_value_well强塞成当前关卡长胶囊（KEEP_ASPECT后只会短在中间）。
当前d88有确定实现错误：level_select_view.gd的_layer先type=sprite，随后merge九宫格却未overwrite，真实变成KEEP_ASPECT TextureRect，导致四行骑白板顶/越底。先修九宫格语义和实际可见白区包含检查，再对原稿注册，不用缩字/挪行掩盖错误。
源格子数字为厚白蓝边艺术字，d88浅蓝细数字也尚未还原；别因为数字值正确就称原稿一致。动态字体许可与原艺术字许可不能混为一谈。

五、验收与文件安全
SOURCE_MANIFEST.json记录9张PNG源路径、尺寸、完整SHA与alpha测量；FILE_MANIFEST.json/SHA256SUMS.txt覆盖包内除自引用manifest外全部文件；verify_package.py仅标准库，运行“python verify_package.py”可核全部字节、PNG尺寸及严格9图白名单，不会改任何文件。
当前d88审计原文见docs/d88_visual_audit.zh-CN.txt；其审计时间早于本次settings_v1允许加入补充包，当前允许范围以本README清单为准，旧“候选未批准”的描述不扩大到其他素材。
先1132×2022/1964实际引擎截图复核，再320/390/430；需要原件整体比例、字面、边距、触区与真实状态一起验。没有像素验收，不因后台功能检查全通过而放行。
本包没有接入工程，也没有上传或联系用户。由root上传一次交用户下载后，在owner侧核SHA/安全解压/独立候选接线；不要覆盖正在试玩的桌面profile或原存档。
