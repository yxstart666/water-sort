# v3候选交付闭包与运行归一化计划

仅枚举实际源文件及SHA256，不复制资源、不上传、不创建虚构res://地址、不覆盖旧freeze。PACKAGE_INDEX.json是源闭包候选，不是直接运行包。published_repository_path全为null，实际publisher须在目标工程落盘后验证。

## 强制归一化

1. 路径源根为本workspace；deliverables/...、cloud_takeover/...由workspace解析，assets/...和../reference2...由对应package根解析，reference2_...由deliverables/water_sort解析。不得统一从layouts目录解析。DEPENDENCY_RESOLUTION.json保留每个JSON pointer、原值、实际源值和有效覆盖。
2. 简中TTC引用统一映射reference2_sc_font_v1/fonts/NotoSansCJKsc-Bold.otf face0；旧英文路径映射reference2_dependency_errata_v1/fonts/NotoSans-Bold.ttf。逐元素font_locale覆盖优先，英语页“简体中文”仍必须SC。两种字体许可一并交付。
3. 940背景为默认；941版仅兼容候选，不同时铺两个背景。统一safe-area变换，不独立拉伸瓶体。A/R采样按MASK_CHANNEL_ADDENDUM。
4. 原模板text_example/text_qa_only是样例，不是初始化数据。真正动态内容必须来自binding。board里QA提示元素必须整项剔除，不能仅抹字或把其rect当玩家文本。所有qa/preview目录、STATIC_QA整屏、技术页脚、中文参照底图禁止进runtime allowlist。
5. 原稿frame/image九宫格可程序组合；QA烘焙面板绝不替代源素材。主页home_bottle_pair是允许的静态插画，不得冒充可动瓶层，但目前液面视觉尚未完成。
6. 48dp触区按实际根变换计算并消除重叠；JSON中44dp旧字段被统一覆盖，不代表引擎已接受。show/hide、disabled、动作唯一性仍需运行验证。
7. 新r2确认优先于confirmations_v1和旧short-modal；新result/energy优先旧同名模板。旧failure/no_moves保留。tutorial pause_with_help优先原pause；主页settings仍原版。不同时装两个pause控件。
8. 返回主页确认仅existing-confirmation条件候选，不新增导航阻挡。13瓶为静态布局候选不是生产最大瓶数。教学为模板，不代表真实关卡已接入或扣费规则改变。

## 闭包问题分级

纯美术/页面状态剩余：主页hero顶液面液感未修；教学手势是否已符合规格需确认；保存失败/待同步如何留在结果页未验证；动态长值极限与所有真实状态装配仍需补。倒水/封口/交付动态验证另由动画包处理，当前索引未擅自收录未终检动画代码。

源模板缺陷：board在elements包含QA footer，应按新增归一化合同排除；tutorial暂停克隆出现8处assets/music|sound路径错误，已退回制作方修正。最终PACKAGE_INDEX.unresolved必须清零或明确阻断。只是文件存在不够，引用必须有唯一根。

旧素材剩余：运行依赖仅保留ui_batch8_home_levels_records_v1/assets/logo_zh.png、logo_en.png两份既定品牌logo；没有旧奶油面板、旧背景、旧大瓶、被拒ui_reference2素材。这两logo为允许品牌例外，不是图2原始像素。旧qa/cork_source.png不进入闭包，改用新main_bottle_cork.png。

生产证据缺失：当前生产原始32态清单和最新场景来源未获得。不能用旧云工程或旧货运游戏清单证明全页枚举，也不能把未知远程排行榜/隐藏色/失败规则新增为产品要求。

运行验收未做：Godot资源导入/逐元素字体、Android safe-area/多分辨率/触控、输入锁、动画体积、SDK回执、真实存档重试、扣体力/attempt唯一性、记录口径。上述不是“缺切图”，须单独作为工程门禁。

## 当前可交付范围

背景、HUD、订单瓶/圈勾、三层主瓶与新主瓶塞、按钮、暂停/设置/语言、主页/选关/本机记录、结果/末关、失败/卡住、能量七态、加载读写错误/锁帮助；新增3/6/8/10/13中英静态布局和状态绘制合同、重玩三分支和条件返回确认、S09阅读帮助/事件引导候选。仅可称“静态可拆素材与装配合同交付”，不称所有生产页面或动态已完整实现。

补充：教学制作方确认父级任务允许合格手势缺省时采用简单点击双圆，故不把“必须新增手势PNG”列为硬缺图。仍须交付双圆的真实目标点绑定与尺寸合同并实际检查。此项不扩大为动画已实现。

## 最终快照更正（00:15 UTC）

tutorial音频八引用已修并冻结，本索引重扫unresolved=0；不再把错根列当前缺项。board以v3.normalization_rules强制删除全部10版qa_notice（包括中文“静态示例”），尚未执行归一化输出，故不能把原模板直接投运行。S09“合法目标”解释仍不够具体，流程规格虽有空瓶/顶层同色，需和当前生产实现核对再补，不宣称完整新手教学已验收。动画已独立交付示例索引，不作UI runtime强依赖。


## 运行模板完成更新（00:20 UTC，最终优先）
已生成reference2_runtime_layouts_v1的98份实际JSON，剔除全10版QA标签、重定位全部资源并分离样例，2123固定根引用检查0错误；不再把归一化留给接入方。主主页hero已采用通过目检的home_hero_composition程序组合，不使用拒收imagegen。tutorial r2六份已覆盖并明确空瓶/顶层同色/有容量，新手信息缺口在规格文案层面修复。结果保存失败用已有save_error条件映射，不强制新页面/事务。当前未闭环仅生产32态与最新规则/入口证据、Godot/Android实际集成验收；静态模板交付不等于生产全状态已验收。
