Stuck / 暂时无路可走 工程素材 v1
设计源已root逐图准入；本包仍需root资产验收和真实engine/MCP逐状态验收。

1. stuck_full_candidate.png是完整915×1719设计原件，不是游戏贴图。manifest给每个组件原始坐标与来源。
2. 默认中文normal优先用 title_normal、hero_card_normal、undo_button_normal、replay_button_normal、home_button_normal、bonus_button_normal 完整原件透明组件；不再把图标/文字缩成另一比例。
3. 独立label/icon只供受控语言/状态UI需要；blank无字材质由imagegen补底，禁止宣称与原始彩色材质所有像素相同。所有不透明资产像素与各自声明源相同。逆合成只用于透明边/接触阴影，避免白色矩形底。
4. hero保持完整原卡画质，不把失败的孤立大箭头alpha候选纳入白名单；卡不是整页背景，正常作为UI illustration texture。
5. panel_blank为真正空panel可九宫格。原图获准的是设计/组件，不是批准生成补底无需验收。浅/深底alpha及原稿重组qa都必须看。
6. contracts/state_layout.json是真实已有动作映射/禁用/条件布局；没有Close X，没有复活。no_bonus少178源像素panel高度并整体居中，不留大白槽；无history禁用撤回并显示原语义提示，移动动作组不压字。
7. pressed/disabled不重画图标：同normal原件用运行时位移/色彩shader表达；qa组件试装展示，不是生产游戏。
8. 320/390/430触区>=44dp。美术natural aspect、mipmap、正确九宫格与actual white-inner containment都要验。
9. qa/source_vs_reassembled_*.png是独立组件重组对比；不是在原整页上盖层假装重组。背景/空panel来自imagegen补底；source_reassembly_metrics.json如实记差异，没有声称100%全屏像素一致。
10. 本目录只有新交付，不改任何游戏代码/用户桌面；原页源和全部生成提示已在上级保留。
