# Settings 五行正式源工程切图包 v1.1

源：`approved_master.png`，915×1719。唯一源为 root 已实际看图准入的 `exec-4fe7d6ca-f58f-4a78-b0c5-679c80aa6dfd.png`。没有混拼旧低清 Settings、没有改游戏代码或部署。

## 交付与接线
- `assets/`：43 个 RGBA；标题完整中文/空底/中文字、关闭完整三态/X、完整框、五行空底与五组源图标/中文字、独立问号与箭头、语言空按钮三态、开关 ON/OFF/pressed ON/OFF/disabled ON/OFF、三层独立柔投影。
- `manifest.json`：源坐标 XYWH、输出尺寸、z、alpha>0/alpha≥128可见bbox及每件SHA。
- `nine_slice/`：72件真实切片；`contracts/frame_geometry_and_nine_slice.json`给真实边界。原尺寸重组逐像素等于原组件。图标、字、开关、关闭不可九宫拉伸。
- `contracts/runtime_behavior_contract.json`：五行、实时设置、点击/取消/禁用、语言/Guide、阴影层、适配及待验项目。
- `contracts/typography_pixel_targets.json`：中文原美术字和英文native文字槽。**没有获批英文图片源，不把英文native方案冒充美术准入。**
- `qa/QA_master_vs_reassembled_native.png`：左源裁切参考，右915×1719原尺度独立组件重组。`QA_*_light_dark_native.png`为逐组件深浅底证据。

## 重要约束
1. 语言值必须实时独立渲染；`qa/`内简体中文仅为对照参考，**禁止导入游戏固定显示后再叠语言值**。按钮、箭头和当前值各一层。
2. 中文标题推荐完整 `title_original_zh`，勿再叠字；若用空底才加源字。四张`*_row_original`仅原源静态ON/Guide快捷组合，不能代替可切OFF的动态行，也不得再叠重复图标/字/控件。
3. 透明图从扁平源恢复，不是原生PSD层。normal不透明内核RGB保源；边缘alpha为工程解混。frame被遮挡的顶部及内部移除区用imagegen补底，详细patch在manifest。空行/空按钮只换内部补底，外缘仍source-locked。
4. pressed/disabled/OFF是imagegen状态材质，注册到同一normal alpha，不是声称存在原源状态。六个canonical toggle alpha完全相同；所有toggle尺寸255×145。真实状态操作及最终视觉仍需游戏内验收。
5. `title_shadow`、`close_shadow`、`language_shadow`由原控件轮廓生成平滑投影，RGB(40,74,118)。title offset9/blur7/opacity.34，close offset8/blur6/opacity.36，language offset8/blur6/opacity.34；明确不是原生原投影alpha。先画shadow再画control；不能再重复添加引擎投影。按合约调低pressed/disabled投影强度。
6. 统一缩放优先。native英文必须清晰完整，不能使用破洞字、过细描边、错误纹理采样；320×480及其它要求屏幕仍待实际1:1验收。

## 验证范围
已实际view：源、imagegen补底、同尺度重组、标题/关闭/开关/语言/所有图标和原字/五行底的深浅底。修过标题底色残留、language图标只剩地球、箭头底色矩形、disabled OFF错误勾、图标白边。root已目检中间五行主几何；**本包是资产交付，不代表游戏运行验收、英文验收、部署或关机已完成。**

`approved_companions/`仅按audit/root指示随包附带两张palette正式资产和override，不属于Settings界面新增控件。小图原件120×112；大展示450×443为已准入修复高分源，非小图像素一致。没有混入候选或其它用户标志。

重建顺序：`python provenance/build_assets.py` → `python provenance/finalize_assets.py` → `python provenance/qa_v11_edges.py` → `python provenance/package_assets.py`。按源文件本地路径运行。最后一阶段生成全部SHA和zip；FILE_SHA256不包含自身哈希，zip哈希在包外`.sha256`文件。

## v1.1 边缘返修
Root拒绝v1（SHA d6d600e9…）的声音/手机灰阶台阶、语言钮底白线、箭头灰边和矩形感投影。v1.1只修alpha/边缘去底和shadow：采用非负black-matte下界避免低估alpha后RGB钳位；图标外投影不再在10px硬截断，而在10至30源像素间连续衰减；语言钮以无字无钮的行底解混。图标和文字不透明源核RGB未改。新增`QA_v11_full_white_390.png`、`QA_v11_full_dark_390.png`和五组原生/2×源对照，root已于2026-10-30 14:29 UTC实际看390白底及五组局部，确认硬线/灰锯齿消除、柔影可接受，准入v1.1素材；这不等于runtime验收。

**最终状态：v1.1已获root资产视觉准入。旧v1 d6d600e9包被拒绝，不得再次上游。真实游戏状态、英文native字和动态语言独立值仍待运行验收。**
