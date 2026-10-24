# 银布罩口贴合修复

改图：imagegen只把旧银布顶帽扩宽为贴合瓶口的软布形状，保留织物、折痕和主体比例；不是全图拉伸。新图165×324，同瓶原点。数字仍动态。

生产遮挡：只叠布不足以保证不露瓶口。hidden状态把完整瓶视觉组（后玻璃、液体、前玻璃、可能存在的塞）乘 wrapped_bottle_visible_mask.png，再叠布。mask为165×410，y0..313透明、y314..409不透明。因此只有底层和下部瓶身能露出。该mask只是视觉遮挡，绝不可替换pour_cavity_mask、容量mask或物理数据。揭晓时布和可见mask一起撤除。hidden与wholelock依然独立。

旧→新：reference2_finish_assets_v1/sprites/cloth_wrapper_silver.png → reference2_cloth_fit_v2/assets/cloth_wrapper_silver.png；另新增wrapped_bottle_visible_mask.png。具体坐标和层序见CONTRACT.json。

实看 qa/fit_before_after_native.png 和 fit_before_after_360.png：左旧罩布露出蓝瓶口，中修后罩布＋原玻璃，右修后罩布＋新清透玻璃。仅静态实组件合成，未宣称运行验收。旧文件与工程未改。
