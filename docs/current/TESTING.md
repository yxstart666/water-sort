# 可重复后台回归

需要 Godot4.7.2 Standard 和 Python3。使用 `python tools/run_current_checks.py --godot /path/to/godot`。

脚本先在系统临时目录复制当前白名单项目，导入后运行真实宿主 UI 路由、C3全50证书回放、原并发/FIFO、体力保存/取消/重试及 native adapter 异常测试。测试只使用该临时副本和注入存储，不接触运行中的桌面目录或真实用户存档。`--real-clock` 额外执行真实系统时钟123秒恢复检查，不能用模拟时钟结果冒充实际等待。

完整方向检查可在隔离副本执行 `--script res://tests/water_sort_orders/direction_contract_review.gd`，或 L2/L6 镜像脚本。输出目录需先建立；并发脚本传 `--out=res://direction_review/parallel`，数字脚本传输出文件参数。仓库提供的 runner 会建立必需目录。

所有检查默认 headless；原生视觉、帧节奏、手机触控和真实SDK另验。原历史失败保存在本机固定证据，不将其源/日志作为有效代码混入仓库。当前失败或限制在 STATUS.md 明示，不通过删除断言凑通过。
