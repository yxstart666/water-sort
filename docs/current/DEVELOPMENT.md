# 当前开发与玩法合同

## 入口及边界

默认场景 `scenes/playtest/difficulty_test.tscn` 负责测试 profile、全关开放与免体力注入；`scripts/water_sort/app_shell.gd` 负责业务接线。`scenes/playtest/energy_test.tscn` 使用真实 EnergyService、独立磁盘 profile。两者均不会自动读取或迁移真实玩家档。生产规则仍独立存在；不能把测试 composition 当发布默认配置。

## 模块

- Rules：`order_rules.gd`；展示与输入队列：`order_presentation.gd`；页面：`order_view.gd` / `home_menu.gd` / `pause_dialog.gd`。
- 动画：`art/pour_animator.gd` 与 `board_pour_path.gd`。源/目标横坐标不同则锁定倒向；共享瓶排队，不相交的独立操作可并行；保留全瓶体/水流/时间路径预检。满瓶庆祝不全局锁住输入。
- UI：`scripts/ui_restore/` 的主题、字体、数字、弹窗和触区组件。动态数据不是烘焙样例数字；普通体力倒计时更新不重建主页按钮。字体采用显式白名单和后备，关闭未知系统字体兜底。
- 体力：`scripts/services/energy_service.gd`；进度：`water_sort/progress.gd`。开局、结算及奖励回执需幂等，存储失败不可假成功。
- 广告：provider factory / owned native adapter / reward controller 与业务分离。桌面显式 mock；Android native 接口资格不等于真实 SDK/设备已验证。缺 singleton 不得回退假发奖励。

## 关卡与机制

当前 `data/water_sort/orders_v3/candidates/c3_full50_20261030.json`，50 关，SHA256 `8462bdcf1ff468a075a35cd9ec5d5adceaa48a9dd52a823aaf9de45589eba08f`。L1 完整解 7 次倒水，仅引导首步，后续自主判断；L2 升难，L3 指定色锁，L4 逐层问号。指定色只匹配颜色扣计数，ANY 任意正确完成色扣计数；不得重复回执双扣。仍需真人判断难度，机器解不代表所有选择都能获胜。

保留当前 Catalog/Progress 明确引用的旧数据和基础类，目的为兼容 API/受控迁移验证，不是将旧实验重新作为当前关卡。46 关筛减、10 色、新饮品场景、收藏排行、失败减角实验均未纳入。

## 资源与许可

源 PNG/WebP 自然比例、既有 mipmap 导入设置保留；不能用整屏参考图替代交互。部分带 reference 名字的原图由当前代码裁切/绑定，属于运行依赖。字体/OFL 与音频来源声明随项目保存。位图艺术字不因附有 OFL 就被认证为 OFL 字体；保留其独立来源边界。

## 开发约束

按模块更换实现，不跨业务层散落皮肤条件；一个文件一个 owner，串行集成。冻结源码、测试证据和部署目录分别管理。复核通过只覆盖对应版本/范围；作者只标 ready_for_review，视觉验收与发布批准另行确认。禁止提交凭据、真实存档、签名密钥或缓存。
