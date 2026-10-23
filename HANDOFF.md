# Color Sort · 倒瓶子（独立50关浓色技术测试版）

快照：water-sort-standalone-20261023。目标是独立私有仓库 yxstart666/water-sort，不与货运项目混放；只保留倒瓶子真实运行依赖、共用菜单/设置/体力/本机成绩页与现行代码，运行代码没有改动。默认50关，浓色绘制修复已纳入。引擎配置版本沿用0.3.0-water-sort-50-playtest，固定源码以实际Git commit和SOURCE_FILES_MANIFEST.json识别。

## 本地运行

使用官方Godot4.7.2 Standard。先运行 godot --headless --editor --path . --import --quit，再运行 godot --path .；或在编辑器打开project.godot并运行。默认入口 scenes/water_sort/campaign_v2.tscn，数据 data/water_sort/campaign_v2/levels.json，50关逐关解锁。逻辑画布1080×1920，默认桌面窗口540×960。仓库不含引擎。

体力上限30，新局扣5，通关返还最多5，每120秒恢复1；同一已付费局续玩不重复扣除。旧5关fallback数据及入口仅为兼容保留，不是默认入口。所有非空瓶满且纯色才胜利，撤销免费。广告SDK、全球排行榜、云存档、商店签名未接入；只显示真实本机记录。

## 开发规范与实际环境

V1.2九份Markdown原文位于 docs/development-standard/，固定来源commit4025312802d8b4d4397d8b717699eeb8abbeee47。根AGENTS.md指向规范。本项目为二维Godot，3D流程不适用；开发规范不替代玩法/竞品分析。

实际验收环境为云端Linux x86_64、Godot4.7.2 Standard、GL Compatibility；此前有限原生1080初始及真实0.42秒倒水中帧审阅确认清晰度改进。固定帧审阅不是完整连续动态、色觉可达性、真人难度平衡或Android/Windows实机验收。本地接收会话已找到Godot4.7.2，但新包运行状态须由本地实际核验。

## 范围与校验

根目录SOURCE_FILES_MANIFEST.json是当前所有源码/资源/规范的SHA256清单（生成清单不自列）；SOURCE_RUNTIME_MANIFEST.json列101份实际运行依赖。未包含未引用的货运机器人atlas、教程候选、离线大证书/候选池、缓存、用户存档、凭据或录屏；完整历史开发归档另行保留，本独立库不声称与历史1858项ZIP逐文件一致。目录名中仍有历史美术来源标记，是共用页面仍实际使用的资源，不代表启用货运玩法。字体与音频许可/来源保留在distribution_notices。

## 可运行的小回归

使用 godot --headless --path . --script 后接以下路径：
- tests/water_sort_art/run_art_tests.gd
- tests/water_sort_celebration/effect_test.gd
- tests/water_sort_v1/focus_pause_test.gd
- tests/water_sort_v1/animation_bridge_test.gd
- tests/water_sort_v1/cork_bridge_test.gd
- tests/water_sort_campaign50/selector_test.gd
- tests/water_sort_campaign50/font_readability_test.gd

只提供所选独立回归，不包含需要大型离线证书的完整图/50关解轨迹审计或palette截图夹具。此前完整归档的通过记录不等于这些省略的测试在本库仍可执行。所选测试使用内存夹具；首次手动运行建议使用干净目录，项目可能在.local/userdata写入测试存档，不能只依赖XDG隔离。不要覆盖原货运项目或既有真实存档。

本地接手顺序：核对commit/清单→独立导入→启动50关→失焦暂停/恢复→封塞/庆祝/成绩→Next及主页付费续玩→中英文末页/设置/体力共用页面。未完成实机/连续动态验收，不把“能启动”称作发行就绪。
