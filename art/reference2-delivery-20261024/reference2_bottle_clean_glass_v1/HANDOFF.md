# 清透玻璃前景替换

唯一需要改变的生产纹理是 assets/glass_front_reflection.png。精确旧→新及hash见 REPLACEMENT_MAP.json。副本 glass_back_shadow.png、pour_cavity_mask.png、原BOTTLE_CONTRACT逐字节相同，仅方便校验；不替换物理、坐标、容量或瓶形。

两条内侧反光、肩部白块、底部内椭圆厚圈已经完全删除alpha，不是调暗；验证ROI的alpha最大值全部为0。外轮廓保留约3px柔和蓝灰细边，不能进一步降低。瓶口原形不改，色强适度协调。图像经imagegen减除编辑，再用原轮廓alpha作严格技术归一，避免生成模型改瓶形；保留原边界材质并协调色值，不手绘新瓶形。

主局、主页、帮助、OrderTarget全状态必须引用同一BottleVisual源。当前订单是同165×410组件等比缩到137px高，不使用旧70×137预合成订单瓶。帮助也应复用真实组件，不复用旧静态order_blue图。

QA里的矩形平填只证明玻璃不再遮色。生产必须保留既有液面、温和体积渐变、动态水滴和倾倒效果；不因换前景删掉液体自身层次。不添加厚分层线。

检查 qa/states_before_after_360.png（上旧下新）、qa/main_same_position_360.png（左旧右新主游背景）、qa/order_mini_360_scale.png。这些是静态组件合成，非运行验收，禁止作整屏背景。主游对照顶部订单仍为旧参考截图，不是mini集成证据。

165×410，pivot82.5/400，满线109、底382、4容量、内腔连通mask全部不变。未改工程，未覆盖旧包。
