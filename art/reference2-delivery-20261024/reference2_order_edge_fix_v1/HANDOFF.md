# 白框下沿缺陷修复

确认源 PNG 下沿有青/紫/红杂色细线和离散像素。旧制作程序按金色色相局部换白材质、保留全部原alpha，未清理边缘残色。不是引擎描边。

仅替换 assets/order_card_pending_white.png（157×204）。蓝面板19997个内部像素及原核心RGB逐像素不变；金色完成框、勾、瓶和状态不动。外围约3px采用imagegen局部修复材质，技术alpha去散点平滑；画布和形状不变，边缘可能约1px亚像素收缩。

替换路径见 REPLACEMENT_MAP.json；旧包完全未改。仅pending使用，不能全局替换gold。VALIDATION.json、FREEZE.sha256有检查与hash。

验收看 qa/edge_before_after_400_dark.png 和 white.png（左原始右修复）、native_before_after.png、main_before_after_360.png。全部是静态QA，不作运行背景，不宣称引擎验收。
