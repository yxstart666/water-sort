# 运行模板交付

此包已实际生成98份归一化布局JSON，不是让接入者重新研究如何改原稿。没有游戏代码、SDK实现或存档事务。固定资源根为交付根，即保留deliverables/water_sort内容的目录；文件内PNG/font路径从该根解析。ASSET_MAP列每一资源真实源路径/SHA。禁止从layouts所在目录解析。

## 已完成变换

- 删除所有board qa_notice（中英10版）及qa_label。静态样例液体/数字不留在运行元素，移动到QA_SAMPLE_METADATA.json，该文件禁止打入runtime。
- 已用tutorial r2六份覆盖同key v1；SOURCE_TO_RUNTIME逐份记录真实来源hash和输出hash。
- 动态文本写required_text_binding，附localized_pattern和typed required inputs；绑定缺失时不显示伪造数据。单纯按钮文案保留已定中英文字，不需再猜。
- 动作保留原语义为required_action_binding，不猜真实API。未绑定动作禁用。宿主必须将已有回调/状态映射过来；这不是新增玩法。
- 主瓶液体使用真实stable bottle状态；订单目标瓶按实际color选择8色资源；订单圈/勾按同一order状态选择，替单复位由宿主提供。
- 背景明确干净940图；modal明确使用live caller，不含QA整屏截图。SC/EN字体逐元素face0，字体许可仍随原依赖包。
- 主页优先components/home_hero_composition.json程序组合唯一顶液面，未使用被拒imagegen输出；原烘焙hero只记录QA旧参考，不是首选运行层。
- 保存失败仅复用已有save_error模板，见SAVE_ERROR_CONDITIONAL_MAPPING.json。没有创建待同步事务或假保存成功。
- 触区小于126逻辑像素已扩至126，且声明按实际安全区重新算48dp。输入宿主不可把设计126永远视为48dp；本包未声称Android触控通过。

## 接入时必填

1. 当前关号、能量current/max与次点倒计时、attempt moves/elapsed、订单delivered/required，逐文本pattern输入，不拿QA样例作默认。
2. 页面/页码/实际关卡与解锁状态、是否有可恢复稳定局、真实本机记录及汇总定义。
3. stable bottle id到视觉slot映射、layers/sealed/locked/busy、order id/color/status、实际免费试用资格。
4. 设置偏好、当前语言、SDK真实可用性及当前奖励阶段。
5. 真实导航、恢复、重玩、撤销、保存重试回调；事件引导的已验证成功事件和实际目标节点。required_action_binding.api_name=null刻意表示等待既有API映射，不是函数已存在。

required binding是明确接口要求，不是空成功实现。教学规则现在依规格写明空瓶/顶层同色且有容量；仍需验证当前生产实现一致。S09静态文案不再仅说“合法目标”。

## 证据与限制

PATH_VALIDATION实际从固定交付根解析2123引用，0错误；VALIDATION确认98模板均无QA元素/原始sample文本字段。SOURCE_TO_RUNTIME、ASSET_MAP支持hash校验。所有source freeze未改。样例元数据、脚本和审计文档不是游戏运行依赖。

当前生产原始32态清单仍缺；Godot/Android整局、SDK、存档/扣费、动效未验。此包是可直接给布局适配器读取的素材模板，不是任何引擎都能零代码自动运行的场景。
