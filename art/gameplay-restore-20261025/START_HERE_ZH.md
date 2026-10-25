# 已定稿主局素材补给：先恢复主界面，不等待弹窗

这是 2026-10-25 的范围明确的源素材交接包，不是整套 Godot 项目或整页 UI 覆盖包。

1. 先看 `RESOLVED_RUNTIME_ASSETS.json`，再读 `deliverables/water_sort/reference3_full_pour_demo_v3/ENTRYPOINT.json`、`FINAL_ASSET_DEPENDENCIES.json`、`GAME_INTEGRATION_CONTRACT.md`。所有归档原文件字节未改；父级任务已在用户新授权下安排恢复，文件中旧日期的“未派发/未授权”是历史状态，不构成已经完成接入的证据。此包本身不授予推送或发布权限。
2. 六包按最终依赖顺序安装：瓶体 v2 → 成对 highlight_fix → drape 布 → plus/order hint → pour atlas v3 → full pour v3。严格按根目录别名覆盖旧玻璃/布引用，不寻找被刻意排除的旧像素。容量 4、color ID、mask/pivot/满线合同不变。
3. 已有原图2背景、蓝金控件和主局布局仍在 `yxstart666/water-sort` 的 `ui/restore-assets-20261023`，已读 HEAD `dc5e9f4f8e505bd715f1656fb31fca99a52e04fe`，根 `art/reference2-delivery-20261024/`。不要等待此补包才还原已有主框架，也不要把整个旧截图回滚到最新瓶体之上。此分支没有 reference3 文件。
4. `accepted_tutorial_v4/` 仅有已接受三步图、手指和完成提示，以及精确摘录的双语内容/坐标映射；没有新弹窗底板、边框、按钮、页面脚本或整份配置。步骤 2 的手指要指左瓶身；最终左满绿、右半红，只是一瓶完成。旧模态素材继续保留，只精简内容，不减素材质感。
5. 首页及最新静态水滴调整不在此任务中。原样片 `home_peak_static.png` 仅用于原文件复现和哈希链，不要据此覆盖最新首页。
6. 唯一生产主技术由现协调者确认。保留语言直切、Game Records / All Levels、振动及透明加号热区，保留关卡、规则、存档和未提交修改。不要读/删除/回滚真实存档，不创建第二写者，不改雷霆/彩虹，不推送/发布。
7. 用真实游戏入口验主局双语、倒水容量/方向/快点、封塞/订单/布状态、撤销/重玩/暂停返回。样片视觉认可不是生产接入验收；第一张真实截图后继续完成全部主局与关键回归。

## 素材传输与复现

接收执行器应按当前 Library 官方流程在自身工作区物化，并验证 ZIP SHA-256、CRC 和 `SOURCE_MANIFEST.json`。云端路径不代表桌面路径。先解压到隔离暂存区，禁止直接覆盖项目。看实际 PNG 与已认可 MP4 后再接入。

完整复现原样片：复制解压目录到另一临时目录，确保 Node.js、`@napi-rs/canvas`（此端验证版本 0.1.100）、FFmpeg 可用，再执行 `bash deliverables/water_sort/reference3_full_pour_demo_v3/source/render_preview.sh`。不要在冻结输入目录运行：原脚本会覆盖 qa 视频、ledger 和历史 home_peak 文件。字体/编码版本可影响 MP4 字节；传入的已认可 MP4 是视觉权威，不能把新编码替代为新定版。

源播放器会预加载全部 15 张 flow_frames；04..14 尽管不参与当前效果，保留只是为了原源码原样可运行。25 张 impact_frames 也是复现输入，生产使用根清单中的 4 张 atlas/core/drop PNG。附带的单张 reference2 背景仅为复现闭包。

排除：整屏帧/接收帧输出、旧 v1/v2/v2_1 倒水包、被覆盖的旧玻璃/布、旧 flow_atlas、对比图、候选弹窗皮肤/脚本、历史数值 QA 脚本（它引用旧 v2_1 包）、难度/关卡/业务代码。原合同中的 QA/历史/provenance 路径不应被误判为生产运行依赖；详见 `DEPENDENCY_CLOSURE.json`。

## 已补入原主界面对照

- `user_attachment_review/image(20261023-115241).png`：用户原图2，SHA-256 `355cbe9bded8a282b6b514adc97d4ef36394522589784078cc4263763f1a6008`。是风格/框架参照，不是最新生产截图。
- `deliverables/water_sort/reference2_main_assembly_qa_v1/actual_components_360x640.png`：静态实际素材装配参照，不是运行截图。
- 同目录 `COMPONENT_SOURCE_MAP.json`：历史原主框架完整素材表。它的 `deliverables/water_sort/<包>/<文件>` 对应已发布分支中的 `art/reference2-delivery-20261024/<包>/<文件>`；原表的玻璃/小瓶图按当前 reference3 和已有订单实际状态覆盖，不能回退旧瓶体或复制示例关卡。此表不是本紧凑包所有文件都包含的声明。原图中 home/步数/用时等历史显示不可越过当前已确认 UI 行为。

## 本次打包验证边界

所有归档 PNG 解码、4 个原 JS 语法、动态加载文件枚举及原文件哈希通过。隔离目录的完整播放器重放以退出码 137 提前结束，未诊断原因，不宣称重放成功，也不把它当生产运行测试。该尝试没有修改冻结原件；传入 MP4 仍是原用户认可文件。
