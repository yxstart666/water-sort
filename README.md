# 彩瓶时光 / Color Pause

Godot 4.7.2 Standard。当前为独立测试版：主页使用批准融合图，默认启用真实体力；保留现有 C3 50 关数据和全关选取，未伪造通关成绩。不是正式上架版。

## 启动

首次导入：`godot --headless --editor --path . --import --quit`

启动：`godot --path . -- --dev-test-ads`

默认入口 `scenes/playtest/current_test.tscn`，独立存档 `.current-energy-profile-v1/`。真实体力上限30、新局扣5、每120秒恢复1；同一未完成局重玩免费，通关返还最多5。`--dev-test-ads` 为明确开发模拟，不能当真实SDK广告。

开始按钮呼吸保持关闭，避免已反馈不适；不能据此声称动画已调顺。倒向锁和英文Pause/设置体力刷新修复保留。重玩标题alpha已替换；通关steps/time/next alpha-v3尚缺本地源，当前仍旧资源。新主页原生最终视觉待用户测试。

主测试版不读写已有玩家档或旧桌面测试档。原免体力入口 `scenes/playtest/difficulty_test.tscn` 仅供独立难度排查，当前默认不使用它。

- [当前架构与玩法](docs/current/DEVELOPMENT.md)
- [最新变更及缺件](docs/current/PLAYTEST_UPDATE.json)
- [本次相关验证](docs/current/PLAYTEST_VALIDATION.json)
- [剩余边界](docs/current/STATUS.md)
- [可复现测试](docs/current/TESTING.md)
- [逐文件清单](docs/current/SYNC_MANIFEST.json)
- [许可与来源](distribution_notices/THIRD_PARTY_NOTICES.txt)

仅保留当前运行依赖、必要兼容基类、测试和有效文档。旧失败源、历史快照、缓存、真实存档、构建包和密钥不入仓库。部分运行路径保留历史命名以避免破坏现有资源绑定，不代表引入已作废功能。
