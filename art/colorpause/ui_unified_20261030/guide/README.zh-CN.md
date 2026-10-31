# 彩瓶 Guide · 统一说明页工程素材 v1

## 交付与状态

源：`approved_master.png`，915×1719，等于 `guide_v1/guide_full_v1.png`。规则已为“按卡片要求完成订单，减少卡上的数字；归零后揭布解锁。”。壳/风格由 root 准入；本包是工程 alpha 提取＋必要无字材质补底，**root 已实际查看 corrected_edges_2x 与 dark_half，通过本轮素材切分准入**，不是已部署或游戏实现通过。真实 BottleVisual、动态 caption、实时能量及英文仍需本地实现与 runtime 验收。

- 27 个运行时 RGBA 文件；另 9 个空框九宫原像素切片。
- 1 个动态 caption 源图仅在 `qa/`，`runtime_import=false`，禁止作为固定教程文案导入。
- 原画布坐标、层级、精灵 alpha 包围盒、逐文件 SHA 在 `manifest.json`；总哈希在 `FILE_SHA256.json`。
- 未改游戏代码、未部署；没有假瓶、游戏动作插画、固定 30/30 或固定动态 caption。

## 先看这些 QA

1. `qa/QA_master_vs_reassembled.png`：左为源图组件直接 cutout，右为真分层重组；两边使用同一纯深底，**不是把完整母图藏在重组图下面**。仅 QA 有源 caption。
2. `qa/QA_components_light_dark_native.png`：各件原生尺寸浅/深底边缘；边缘半透明来自扁平图推断，并非声称有原生 PSD 分层。
3. `qa/QA_three_step_states_and_cta.png`：三步骤状态与 CTA 普通/按下/禁用材料，所有状态同 alpha。
4. `qa/QA_blank_frame_light.png`、`qa/QA_blank_frame_dark.png`：纯空框检查。
5. `qa_selfcheck.json`：RGBA、坐标尺寸、透明 RGB 清零、无裁边、状态 alpha 相同均通过。源提取原字/原控件确信不透明像素 RGB 最大差 0。

## 接线不能改变

- `manifest.json` 全部 `rect_xywh` 是 915×1719 左上原点坐标。整个根节点统一等比缩放＋统一偏移；不得各控件单独缩高度、挤压字或凭“同字号”排版。
- 宿主继续用已有背景，不要将 approved_master 整页贴回去；图只作核对。
- 主层顺序：空框 → 真实 BottleVisual → 三步骤底/原字 → 实时 caption → 原规则字 → 标题/CTA → 返回/实时能量。
- 中央 BottleVisual 槽 `[104,560,707,524]`。必须原有真实节点、选中/倾倒/完成状态，不用本包创造玩法。
- caption 槽 `[200,1094,510,151]`，由现有 help state 的文本驱动；源示例是参考，不是固定内容。
- 能量数字槽 `[118,71,115,46]`，优先使用首页共享能量控件；本包空胶囊为可选。任何数字都来自实际能量服务。
- 保持现有 **2-step 右侧源瓶 → 左侧目标瓶** help 状态机。“1选右瓶 / 2倒绿色 / 3满瓶”只是视觉阶段，不新增三个业务步骤。
- “知道了”仍接 `home_menu._reference_notice` 的 `close_help`，返回仍接已有关闭/返回；不加奖励或改订单规则。

## 中文原字与状态

- 标题普通态用 `title_original_zh`。空标题 `title_blank_normal` 供本地化/动态标题，不要和有字原件同时叠。
- CTA 普通态可直接用 `cta_original_zh`；需多状态时用 `cta_blank_{normal,pressed,disabled}` 加 `cta_label_zh`，原坐标精确叠加。
- 三步可直接使用各 `stepN_original` 还原母稿首态。变化状态用 `stepN_active/inactive` 加 `stepN_label_zh`。所有状态保本步骤原 alpha，不改变命中框。
- 副标题、规则、步骤/CTA 静态中文均原像素，未重排字形。源是生成艺术字，**不能确认准确字体名称**。
- 动态 caption 源两行深蓝实墨高 53/52px、宽 282/476px、行顶 y1109/1177；看 `contracts/typography_pixel_targets.json`。runtime 字体必须用实际墨迹/advance 校准，不直接照搬字号。中文静态精准裁取不意味着动态字体精准复刻。
- 本轮没有已批准的英文源图。英文使用空底＋项目统一 runtime 字体，是待 runtime QA 的本地化候选，不假称英文艺术字已获批。

## 哪些是原件，哪些是重建

- 原中文、原按钮正常态、返回的确信前景保源 RGB；轮廓由源色彩分离和 常规 3px trimap 推断；步骤外缘另用测得的白底红通道反混色恢复软影，避免白边/横向突刺。透明 RGB 全清零，straight alpha；引擎仍应用既有边缘扩展/过滤设置防黑边。
- 空框有色外框保原可见像素；整个浅白内区由 imagegen 无字编辑恢复，以免擦字后残留白色字边。它是明确补底，不声称该内区所有像素来自母稿。
- 空标题/CTA 仅文字遮挡内部取 imagegen 补底，外轮廓及 alpha 不变。
- 步骤空底内部采用 imagegen 去字材料；active/inactive 在各自固定 alpha 内注册母稿的亮青/浅蓝材料。不同步骤原本宽度不同，已按各自源坐标保留；不是随意统一控件外形。
- CTA 按下/禁用材料由 imagegen 新建，再注册到原 CTA 内部，源边缘与 normal alpha 完全一致。新状态是工程候选，不伪称从母稿直接裁出。
- 生成材料原始结果保存在 `provenance/`；构建/验收脚本只裁切、alpha 提取、注册/合成和 QA，没有程序绘制替代 UI 或字体。
- `contracts/frame_geometry_and_nine_slice.json` 给出主框九宫边距 `[115,172,115,115]` 及实体九切片。优先统一缩放整框；若必须适配，只拉伸平直边，不改圆角/步骤带/内部内容坐标。

## Root 边缘复验修正

已修标题顶缘误纳入背景亮带造成的细矩形台阶；步骤2/3底缘改用源白底红通道反混色，消除最近颜色投影造成的横向蓝刺，保留柔和源阴影。正文墨迹与位置未变。新增 `QA_corrected_edges_2x.png`、`QA_rebuild_dark_half.png`、`QA_rebuild_light_half.png` 以及同尺度50%叠合/8×差图供复验。

所有分层恢复存在扁平输入的 alpha 不可辨识性；因此以浅/深底和重组 QA 加 root 实际检查为准，不用“像素完全相同”掩盖补底或材料变体。
