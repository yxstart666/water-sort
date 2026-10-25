# 已定稿主局素材：GitHub 交接入口（2026-10-25）

此目录是原补包的 **109 个文件逐字节解包副本**，另加本说明和 `GITHUB_FILE_MANIFEST.json`；不覆盖 `art/reference2-delivery-20261024/`，不修改游戏代码或 main。

## 使用顺序

1. 先看本目录的 `RESOLVED_RUNTIME_ASSETS.json`、`DEPENDENCY_CLOSURE.json`、`START_HERE_ZH.md`，按最终依赖顺序接入瓶体、highlight fix、布、加号/订单提示、倒水 atlas 和 full pour。
2. 原图 2 的主框架及既有蓝金素材仍在同分支的 `art/reference2-delivery-20261024/`。本目录补齐 reference3 素材、源文件、已认可 MP4、原图与装配对照，以及 `accepted_tutorial_v4/` 的已接受三步内容/手指/完成提示。**不含被否决的简化弹窗底板、边框、按钮或页面脚本。**
3. 各相对路径以本目录为补包根；不要把整包直接覆盖游戏工程。按原合同/清单映射到工程，仅替换必要主局素材。保留最新业务行为、存档、语言切换和未提交修改；旧原图不能覆盖最新瓶体/首页。
4. 原文保留用于哈希审计。`START_HERE_ZH.md` 中“Library 物化”“此分支没有 reference3 文件”等是发布前状态；现在直接从此 GitHub 分支读取。源码文件中的历史“未派发/禁止推送”不代表本次素材交接没有授权，也不额外授权消费者提交、发布或改其他项目。
5. 必须在接收端检查实际 PNG 与已认可 MP4，再从真实游戏入口完成主局双语及关键操作回归。素材交付不等于生产接入验收；隔离播放器完整重放此前以 137 中止，原因未诊断，不能宣称完整重放或生产运行已通过。

## 完整性

- 原包：`ColorPause_Gameplay_Reference3_and_Accepted_Tutorial_V4_20261025.zip`
- 原包大小：5,262,335 bytes；本次不重复存放 ZIP，以上 109 个文件全部保留。
- 原包 SHA-256：`c14c29b217931e4d8ad7f4893eec69fee8620289980c2e6f4b1a0cf655350997`
- `SOURCE_MANIFEST.json` 保留 103 个原始文件的来源与 SHA-256；`ARCHIVE_FILES.sha256` 保留归档原清单。
- `GITHUB_FILE_MANIFEST.json` 列出本次解包的全部 109 文件及本 README 的相对路径、大小、SHA-256 和 Git blob SHA；清单自身不作递归自包含。

读取本素材分支与本目录即可，不必等待下载工具。仓库维持私有，且只新增本目录。
