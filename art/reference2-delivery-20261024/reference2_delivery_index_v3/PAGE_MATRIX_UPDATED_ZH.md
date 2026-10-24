# v3页面覆盖更新（候选源快照）

此表覆盖本次已知页面家族。基线逐页文件与缺口详见reference2_page_coverage_audit_20261024/AUDIT_ZH.md；所有实际源路径与SHA见本目录PACKAGE_INDEX.json。

| 页面 | 当前选择 | 静态可还原结论 | 剩余门禁 |
|---|---|---|---|
| 主游戏中英3/6/8/10/13瓶 | reference2_board_layout_completion_v1/layouts/board_{3,6,8,10,13}_{zh,en}.json | 10个布局已出，实际看13EN与状态集；待真实数量映射 | qa_notice剔除；背景/字体归一化；生产瓶数证据；动态状态/安全区实机 |
| 主瓶封塞 | reference2_main_cork_completion_v1/assets/main_bottle_cork.png、CORK_CONTRACT.json | 独立透明素材与锚点齐，已看深浅背景 | 新去底纹理略重绘，非原PSD；真实动画对齐未验 |
| 选中/合法非法/锁/忙/辅助/封口待匹配 | board STATE_CONTRACT.json | 八态程序覆盖规则+QA齐，不强求八张PNG | 状态真实来源/先后级/液流封口交付动态未验 |
| 主页 | 旧home_{zh,en}.json | 可装基础页 | hero液面视觉待修；Start/Continue/全通关动态样例未验 |
| 选关 | 旧levels_page{1,3}_{zh,en}.json | 可装参数化页1/2/3，不缺第2页切图 | 第二页动态生成/实际解锁数据待验 |
| 暂停 | tutorial/layouts/pause_with_help_{zh,en}.json优先 | 含帮助入口候选 | 音频状态资源错根修复中，不能提前全通过 |
| 设置/语言 | 旧settings/language_{zh,en}.json | 可装 | SC逐元素映射、48dp、8组合实机待验 |
| 重玩三分支 | confirmations_completion_r2/layouts/restart_unfinished、replay_settled_enough、replay_settled_insufficient各双语 | 已补齐可装 | attempt/扣费一次/取消零副作用待验 |
| 返回确认 | r2/return_home_{zh,en}.json | 条件候选可装 | 仅真实已有确认时启用，不新增阻挡 |
| 普通/末关结果 | r2/result、result_final各双语 | 标题、关卡号、按钮、统计可装 | 保存失败/待同步状态呈现尚未完成验证；same-attempt统计和+5动画 |
| 失败/卡住 | 旧failure、no_moves、no_moves_no_undo各双语 | 可装 | 业务是否有明确失败、队列稳定及真实Undo |
| 能量七态 | r2/energy_{unavailable,ready,loading,offline,failed,full,insufficient}各双语 | 当前值、次点倒计时、满值隐藏可装；noSDK不足文案已修 | 广告播放/取消/写失败映射与SDK凭证；ready不代表SDK存在 |
| 本机记录3态 | 旧records_{empty,data,overall}各双语 | 可装 | same-attempt或分项最优真实模型、汇总指标、返回来源 |
| 全球排行榜 | 无新增 | 未确证支持，不伪造 | 有真实后端才补远程态；无后端非必需新增 |
| 加载/读写错/锁关/L4帮助 | 旧misc各双语 | 短层可装 | 启动整页/不兼容映射、安全保存/重试接口 |
| S09玩法阅读帮助 | tutorial/help_*双语 | 正在终检，不能先全通过 | 玩家文案、无匹配例子与棋盘一致性，资源根修复 |
| S09事件引导 | tutorial/guide_*双语 | 事件门禁+高亮+双圆点按候选 | 实际目标选择、合法倒水、等待/下一步、关闭保持原局的实机验证 |
| 倒水/交付/胜利等动画 | 独立动画worker | pending，不包含未终检文件 | 完成后增量索引/视觉及运行验证 |

最小未闭环清单分三类：
1. 纯美术/布局：主页hero液感；结果未保存/待同步呈现；tutorial终检和board技术标签剔除；新动画增量。
2. 生产证据：当前原始32态清单、真实生产入口/资源版本、实际瓶数/辅助瓶边界、明确失败与榜单能力。
3. 运行验证：Godot导入/Android触控字体安全区、数据绑定、状态优先级、存档恢复与错误、安全退出、SDK及扣费去重、倾倒守恒和动效。

三类不可混称“切图没做”，也不能因静态文件齐就宣称全游戏完成。

## 最终快照更正（00:15 UTC，优先于上表施工状态）

- tutorial已冻结；8处音频on/off依赖路径已修。本次重扫849个源引用，unresolved=0。30模板已入候选索引，S09高亮+双圆点击已实看。但“合法目标”尚未清楚向新手解释同色/空瓶/容量具体规则，属教学信息可理解性未闭环，不能称完整教学验收。
- 依据docs/flow_reset_v1/SCREEN_STATE_SPEC.md S03/S09，文档确有“只能倒入空瓶或顶层同色的瓶子”及相应英文要求；当前生产规则仍需与最新订单实现对齐。本轮制作方选择保守文案，具体教学规则必须后续核对补足。
- board qa_notice为两语共同技术标签元素id，v3强制剔除全10份，不只通过英文关键字筛查到的5份。其source_template不直接作为运行场景发布。
- 动画包已完成独立示例，可按OPTIONAL_ANIMATION_DEMO_INDEX.json交付33个实际文件快照，不纳入UI运行强依赖；不是生产实机验收。
- 主页新imagegen候选已拒收，原hero保留；组件顶液面修复另行处理中，当前不计通过。


## 运行模板完成更新（00:20 UTC，最终优先）
已生成reference2_runtime_layouts_v1的98份实际JSON，剔除全10版QA标签、重定位全部资源并分离样例，2123固定根引用检查0错误；不再把归一化留给接入方。主主页hero已采用通过目检的home_hero_composition程序组合，不使用拒收imagegen。tutorial r2六份已覆盖并明确空瓶/顶层同色/有容量，新手信息缺口在规格文案层面修复。结果保存失败用已有save_error条件映射，不强制新页面/事务。当前未闭环仅生产32态与最新规则/入口证据、Godot/Android实际集成验收；静态模板交付不等于生产全状态已验收。
