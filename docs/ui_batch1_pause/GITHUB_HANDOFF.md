# UI第一批：暂停窗口切图安全接入

本分支只交付原生暂停切图、参考图和接入文档，不包含订单玩法实现；不得merge整个分支或reset/checkout覆盖本地工程。用户现有orders_v3以及61个未提交文件必须保留，尤其order_view.gd/order_hud.gd；先备份或提交，再选择性拉取所需路径。main保持不动。

## 取用路径

- assets/：本批保持原相对路径的38张真实透明PNG、字体/许可和布局状态JSON。仅复制本批PUBLISH_MAP.json列出的文件，不要把整个远端assets目录覆盖到本地；同路径同hash复用，不同hash停止并报告，不覆盖。
- docs/ui_batch1_pause/HANDOFF_ZH.md：完整交付说明。ASSET_MANIFEST.json、contracts/DEPENDENCY_RESOLUTION.json与PAUSE_RUNTIME_CONTRACT.json在本目录，按原生941×1672参考画布等比适配。
- references/ui_batch1_pause/：完整效果图和清点图，只作参考，非runtime切片。
- references/ui_batch1_pause/reference_code/**/*.gd.txt：原组件只读示例，添加.txt防止Godot将其当作运行脚本扫描。不能整体复制成scripts目录或接入货运业务。原包HANDOFF中contracts/reference_code的提及对应这里，完整映射见PUBLISH_MAP.json。

本包只提供切图与契约，未修改/启动用户本地订单工程，未验收本地UI整合。暂停视图应发出resume/restart_requested/level_select_requested/preference_changed，业务路由与动画事务继续沿用本地实现。重玩确认、外侧点击/Escape优先级、音乐音效持久设置、语言展开与44逻辑像素触控目标仍须本地验证。不要将旧教程按钮连到货运教学。

## 发布范围

该提交相对基线只能新增assets/references/docs路径；没有scripts、scenes、project.godot或现有资源的不同hash覆盖。字体20MB通过同库已验证blob复用，并保留许可。38PNG的哈希、尺寸与真实透明通道已复核；“透明素材可用”不等于已完成订单工程的图形/交互验收。
