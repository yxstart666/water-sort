# 指定色锁卡 8色美术工程包

## 可直接使用
- `runtime/card_shell_reusable.png`：批准 ANY 卡壳原字节拷贝，326×456。
- `runtime/target_<color>_card_layer.png`：同尺寸透明叠层，仅指定色瓶；原点(0,0)、scale 1、centered=false，与卡壳叠放。
- `COLOR_MAPPING.json`：真实8色 red/orange/yellow/green/blue/purple/pink/cyan，含palette来源、RGBA原件、可见bbox及几何变换。
- `scene/specified_color_card_art.tscn`：仅美术参考装配；不包含条件判断、解锁逻辑和烘焙数量。
- 动态数字继续绑定真实 `condition.remaining`；原 `approved_any_count.gd` 是现有Noto字体方案，不是源图精确字形。C3实盘统计只有1/2，因此可直接复用现renderer，无需扩数字。

## 严格边界
zh/en共享无文案瓶图标；不要重新增加“蓝色订单”等描述文字。ANY保留其原中性票据+勾图标及真实count，不允许指定色退化成ANY。

unknown color须开发明确报错并使测试失败；不能静默只盖布、不能代用蓝色、不能偷换条件。remaining≤0由既有解锁流程处理，不显示过期×1。本包没有更改任何规则、UI业务脚本、关卡和广告条件。

## 几何与alpha
原米白布677×1917、原位置和alpha未改；卡位置(31.202222222222,88.646666666667)、scale .3177777777777778保留。具体坐标见`LAYOUT_AND_STATE_CONTRACT.json`。

所有颜色原图均由内置imagegen编辑生成，原始RGBA和prompt保留于source目录。原图内低于1/255可见性的alpha=1杂点也保留，runtime仅做统一等比缩小、透明叠层几何装配，没有程序重绘、改色、造新卡壳。运行时图标没有文字或数量。

## QA而非机制验收
qa目录含整卡8色、104×145/40dp/52dp深浅底、原蓝卡/原卡壳/新蓝卡同形比较、ANY对照、原布装配。

最小实际绘制矩形为19.466×27.229px（L26、11瓶、320×480；不是Android dp，也不是alpha bbox）。`qa/true_minimum_19p466x27p229_light_dark.png`有真实比例和5倍最近邻观察版。目标色仍可区分，但瓶细节约6×13px、数量约7×10px，不能宣称舒适可读；是否需要layout放大由root实际游戏窗口验收决定，本包不改layout。

QA中的数量为Pillow/FreeType按现字体与基线绘制的示意，不是Godot实渲，也不是运行时纹理。root仍须验收50盘真实color/remaining映射、中文/英文切换、正确订单递减、错误颜色不递减、归零解锁、重开/暂停恢复和实际最小窗口。美术齐备不代表机制已验证。

C3统计：22个指定色锁均required1；blue4/green4/orange1/purple3/red3/yellow7。另5个ANY：L15/40 required1，L25/35/45 required2。pink/cyan虽无本轮C3锁，仍按真实palette完整预支持。
