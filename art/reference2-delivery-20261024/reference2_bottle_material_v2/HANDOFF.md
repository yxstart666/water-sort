# 玻璃材质 v2｜已通过 root 静态审图

只换 glass_front_reflection.png。imagegen原创材质编辑＋透明内腔局部修正，蓝灰玻璃壁厚、瓶口肩部统一，局部肩反光不下延为两条长白柱；底部只保留外壁，不画挡色内椭圆。中央瓶体alpha最大0，底内中央最大6/255。没有液体颜色烘入玻璃。

back、pour_cavity_mask和原contract字节不变：165×410、pivot82.5/400、fill109..382、容量4。生成材质注册回原轮廓并裁切，原外轮廓外非透明像素0。精确映射见REPLACEMENT_MAP.json。主局、主页、帮助真实组件、OrderTarget等比mini共用新前景。

8色数值见PALETTE_SUGGESTION.json，仅视觉参数，不改color id、关卡、订单或排序规则。blue=#159CFF蔚蓝、cyan=#19D4CF青绿；purple=#A246F2紫、pink=#ED3BA7玫红、red=#F33B36暖红。不宣称所有色觉和小屏均完美，需实机检查，辅助符号另议。

液体实施只读取 LIQUID_RENDER_CONTRACT.json，不能使用旧ry4/ry7试验参数。具体顶面、内部前弧、重力平面和容量约束见文末当前唯一入口。

兼容reference2_cloth_fit_v2：wrapped visible mask只用于整瓶视觉渲染遮挡，不是液体容量/颜色规则mask。揭晓同时撤布和遮挡mask，整个组件正常显示，数字独立动态。

已审预览冻结：qa/five_states_native.png、qa/main_lineframe_vs_material_360.png。8色同屏：qa/palette_eight_360.png。qa/cloth_compatibility_native.png是遮罩兼容合成。均为静态组件QA，不是实机验收，禁止当运行背景。原旧文件/生产代码未改，未上传。

## 当前唯一实施入口

先读 IMPLEMENTATION_ENTRYPOINT.json。玻璃与八色保持；液体只按 LIQUID_RENDER_CONTRACT.json：原生可见宽126，顶面总厚28（ry14，比0.222），内部共享前弧深10（比0.079），内部不画白边/亮面圈。满线109是体积平面中心，顶面仅作投影视觉展开；倾斜/容量使用同一求解平面和内腔。旧ry4与ry7一律superseded，不是技术自选项。当前审图已通过：liquid_depth_ratio_pair_native.png与liquid_depth_ratio_main_compare_360.png。
