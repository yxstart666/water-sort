# Reference2 收尾资产

仅接入 sprites/ 四张 PNG；真实 RGBA alpha，透明边界，无假透明底板。全部尺寸、alpha统计和 SHA256 见 manifest.json，坐标见 CONTRACT.json。未改工程、未改旧 freeze、未上传。

- 银布 165×324，与原瓶 165×410 同原点叠在玻璃前景之上。柔软折痕、织物纹理，不烘数字。底边比底层起点313.75略低，避免上层色块从波浪边漏出。仅底层可见。中心动态数字区域 [38,145,89,70]。hidden 内容揭晓和 whole lock 的逻辑必须独立，不能因为布出现就禁用瓶子。
- icon_video_ad.png：录像机＋播放三角，两处使用同一张；不写广告解锁文字，也不叠加号。保持已有广告可用、加载、失败、完成状态逻辑。
- plus_button_base.png：原批准蓝金空底直接复用。plus_gold.png：独立立体金色加号，居中放置，宽度约空底55%。energy_plus_detail.png只作组装示意。
- 暂停窗口不重画。优先恢复已交 pause layout：关闭视觉158×64，开关视觉164×72（940基准），复用 step_pill_blank.png。48dp invisible hit区域不能扩张视觉；检查 minimum size、stretch、hit rect误作visual rect。
- 体力和关卡框中心Y对齐。以上按钮最终以实际360宽截图确认可读性。

qa/main_same_position_compare_360.png 是批准 reference2 主游同位静态对照，每侧360宽，不是运行截图、禁止当背景。qa/wrapped_bottle_native.png 为原玻璃瓶实尺寸合成。预览数字1、体力30/30只是独立示例文字。

生成来源：built-in image_gen。银布提示为银灰柔软织物紧贴瓶口肩部、只输出布、透明背景、中央留动态数字区；视频图标提示为奶油金色录像机带深蓝播放三角，后续去除外部光晕；加号提示为等臂金色珐琅立体plus，不含底。全部只做技术裁切/缩放和静态组装，未重画玻璃或其他UI。
