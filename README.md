# 彩瓶时光 / Color Pause

Godot 4.7.2 Standard 项目。当前同步的是已交付桌面测试的 `8e989ad5` + 已独立复验的设置页体力刷新/英文暂停布局修复 `d333e84b` 有效源码及运行依赖，并加入独立体力测试入口。它不是商店发布包，也不是全 UI 视觉最终签收。

## 启动

首次导入：`godot --headless --editor --path . --import --quit`。

默认 `godot --path . -- --dev-test-ads`：C3 全 50 关可选、免体力，独立测试档，无伪造通关记录。

真实体力测试：`godot --path . res://scenes/playtest/energy_test.tscn -- --dev-test-ads`。初始 30，开新局扣 5，同一未完成局重玩不重复扣费，通关返还最多 5，每 120 秒恢复 1。该入口独立存档，F8 仅模拟奖励保存失败。

`--dev-test-ads` 是显式开发模拟，不是真实广告服务。默认开始按钮呼吸关闭。不要拿桌面测试配置直接上架。

## 开发与验收

- [当前架构与玩法](docs/current/DEVELOPMENT.md)
- [当前状态和边界](docs/current/STATUS.md)
- [运行回归](docs/current/TESTING.md)
- [同步文件清单](docs/current/SYNC_MANIFEST.json)
- [第三方声明](distribution_notices/THIRD_PARTY_NOTICES.txt)

旧文件夹名字中的 reference、candidate、experiments 不自动表示作废：仍被当前运行代码/兼容 API 引用的文件按原路径保留；已退役演示、旧报告、失败实验、构建包、缓存和真实用户存档不在此工作树。历史 Git 提交不重写。
