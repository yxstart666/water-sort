# 生产32＋24状态与98候选模板绑定补充

本补充优先于此前“缺生产原32态证据”的结论：现已获得原32项及另24项完整源码核对正文，来源thread 01a16664-826e-7440-9e3d-5c5169540037、turn 01a16b6b-3f9f-77f6-8a1a-017f3d15a14c。它不是GUI或视觉通过证明。仅新增本目录，不修改首批发布源、freeze、旧索引或生产文件。

STATE_BINDING_MAP.json逐98模板给出来源hash、56本地state反向索引、入口/退出、语言、资源路径+hash、真实挂点语义、是否新增业务入口及截图对状态。fixed_commit在未获publisher确认时为null，local_runtime_acceptance全部null；不得虚填已验。

## 必须阻断的直接套用

1. 主游戏实际orders_v3为1080×1920，候选940×1672；暂停实际941×1672。主游不能简单用一个缩放因子替所有系统。可先定义contain s=min(1080/940,1920/1672)，再加offset和实际safe area，但须结合two_rows/bottle_slot真实一/两排重新落位。13瓶三排候选不自动成为生产布局。所有锚点、接收区、嘴位置、前景遮挡一并转换，保持瓶体等比。暂停单独941基准，不能暗改它为主游戏1080。
2. 主页保留assets/branding/approved_white_red_blue既有用户批准白底Logo。候选ui_batch8黄色字logo不覆盖生产。候选hero组件可独立评估，不把Logo和hero绑定成不可拆整页。
3. final_win真实动作ReplayAll、重玩末关、Home。候选Choose level不能代替ReplayAll；不出现Next51。普通win的候选records链接没有默认生产入口，不因有图启用。
4. leave真实为稳定checkpoint后直接离开；pause“主页选关”实指levels，结果Home实指home。return_home确认属于未实现leave_confirmation，整模板不挂默认入口。保留真实路由并纠正文案到选关，不擅自改为回主页。
5. game_rules默认不可达，仅show_instructions API；生产主页设置已有home_rules。候选pause_with_help不得自动增加默认游戏说明入口，整套六步事件引导也非现成流程。first_guide只第1关moves=0，零基源3→目标4，成功首倒退出，不串联新steps3..6。
6. L3 mask_intro解释下层隐藏色、实例首次load_level(2)，顶部仍可倒；L4整瓶锁是瓶1，首单收件解锁，可撤销复锁。已有锁PNG/锁教程不能覆盖隐藏色。mask_intro需要独立文案/可视遮罩绑定，当前98没有直接匹配模板。
7. bonus_bottle与bonus_slot每局各自独立local_trial确认，未接广告；表现忙不打开。98没有这两个独立确认合同。共用蓝金面板可复用，但须为现有两个操作分别绑定明确文案、confirm/cancel和资格，不套重玩扣5或广告ready。
8. 能量满30、非满≥5补给、<5不足、snapshot不可读--/30四种需要明确分流。ad_unavailable不等于energy_unreadable；无广告领取按钮绑定，不给未来ready/loading/failed/offline模板真实入口。恢复每120秒1点，每秒更新snapshot。unreadable只有关闭/后续读写，不添加远端修复。
9. check是flight到达后的短暂标记，slot_exhausted是没有后续任务的持久空槽。不能共用一个bool永久勾；replace复位由真实队列，绝不随机生成新订单。生产要求白框→金框大勾时，现旧ring/check切片只是候选不能冒充最终帧。
10. 已有full_ready接点并非orbit-stars API。环绕星动效需要新只读表现adapter，采现有满瓶/封口状态并响应pause/cancel，不写rules.delivered、不单独解锁、不奖体力。现有LevelCompleteEffect与瓶身环绕星不同。

## 可复用与明确缺绑定（不是要求新增业务）

- undo映射主游戏按钮与真实历史：恢复盘面/步数/订单/遮罩，不倒退思考时间，保留已领取辅助；忙及完成后按真实可用性。
- stuck实际含撤销、重玩、主页、可用RescueBottle；no_moves两按钮候选不代表全动作覆盖。无历史BlockedUndo禁用。failure不对应独立已实现输局，不新增失败规则。
- ranking_level用进入时continue_index，同一次最佳步数/用时，无任意关选择器；ranking_total为本机完成数与各关best用时汇总。非主页origin API不可达不等于可公开入口，无全球榜。
- save_error是本地动态notice，读取/写入/偏好/结算失败都走真实文案和关闭/后续重试。现read_error/save_error图可以提供底板，Retry不能凭候选文案虚构可用回调或网络恢复。
- 音乐/音效真实独立持久；失败保留旧值并提示。语言expanded阻挡穿透，Outside/Escape优先收起。两来源各16组合，32组合不是32业务页。
- 8色固定EB3043/148BE8/F2D414/11B866/A651F3/F57810/ED29B2/13CBD7；云端有cyan订单素材，生产旧套缺cyan时可绑定动态真cyan，不能近色替代。完整瓶用同玻璃/液层/塞组合，不强制把八色成品烘成不可动PNG。
- UI_SLOTS只是登记点，不是通用模板加载器。98 JSON不是98可直接运行scene；owner须写适配器，将required semantic字段映射真实挂点，不能把模板样例当游戏数据。

## 范围明确排除

hint、leave_confirmation、network、other_services、cycle_deadlock无默认实现。登录、支付、云存档、分享、全球榜、自动提示、广告播放不在本次上线范围。循环死局仅隔离测试风险，不新增求解/规则。classic_modes显式旧场景保持独立流程与存档，本轮不改也不在默认主页加模式切换。

## 最小集成验收门禁

- owner在固定commit拿到逐文件hash并实际挂接，批次保留回滚。
- 第一批先主页Logo不替换、主游坐标与瓶体、暂停来源路由；随后实际trial/energy/final/stuck分支。
- 逐状态ZH/EN截图对：candidate可读路径已列，真实acceptance待owner填；不把来源源码已实现标为视觉通过。
- 保持current_attempt、ledger、display_delivered及事务队列权威；表现只读取/延迟展示，不能重复发奖或占瓶。
