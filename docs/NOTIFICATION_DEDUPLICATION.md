# 通知防重与单次补发（2026-09-15）

## 问题与实现边界

- 录屏中，09:00、提前 5 分钟的同一条提醒在约 08:55:34、41、49、56 重复弹出，应用内提醒列表仍只有一条。旧共享服务在一分钟补发窗口内，每次对账都重新计算 `now + 5s`；通知从平台 pending 列表消失后会被误当成需要补发。录屏序列回归在修复前产生一次原排程和四次额外调用。
- Windows 3.1.1 插件的原生实现对同 ID 调用 `AddToSchedule` 会追加副本；`cancel(id)` 只移除第一个匹配副本。非 MSIX 无法可靠读取或撤回已显示历史，但可以读取／移除待发项。原生测试验证了三条待发副本归并为一条；不能据此断言历史“三连通知”的所有触发条件都已复现。
- 选择 **优先避免重复**：平台接受排程不是实际展示证明，结果不明时不自动重放。这个策略不承诺操作系统层面的“恰好送达一次”；异常退出、撤权、ROM 行为等情况下仍可能漏提醒。

## 防重契约

1. 登记身份为数据代际、逻辑提醒键和原定 UTC 时刻。标题、语言、布局变化不重置身份；不同发生次数、提醒偏移及真正改变后的时刻独立。时间比较按绝对时刻，不因 UTC／本地表示不同重复登记或漏清理。
2. 沿用运行时互斥锁：先写 `pending` 占位，再调用平台，完成后写 `accepted`。确定未进入系统排程的失败可以记为 `rejected` 并重试；不确定失败保留占位。即使平台调用成功后登记写入失败，也不会在逾期恢复时重放。
3. 正常未来排程也登记。真正缺失的未来原提醒／稍后提醒可在到期前修复；过去的已登记项不得因 pending 或 active 列表为空而再次补发。看见相同 ID／时刻的真实待发项可以确认系统已接受登记，空列表不能反证“没发过”。
4. 未登记且仅逾期一分钟内的提醒，在首次决策五秒后补发一次。后续对账保留首次时刻，不能顺延、重复添加或误删尚待触发的补发项。超过窗口不补发。
5. 即使总开关关闭或平台条件受阻，也在首次对账建立历史起点。升级前无证据的逾期历史不盲目重放；已有平台／背景请求元数据迁移为接受证据。没有新登记存储能力的自定义存储保留未来排程，但禁用自动逾期补发。
6. “稍后 10 分钟”以原通知卡片键、发生版本、卡片触发时刻的哈希保存动作凭据；同一旧动作跨引擎、重启、过期后不重新计时。新稍后卡片上的明确动作可以再提醒。已处理／删除／停用的原有取消规则仍保留。
7. 新增 `AgendaNotificationRegistrationStore` 可选接口和无正文的登记／动作凭据模型；内存及 SharedPreferences 存储都实现代际守卫。键前缀 `sked.notification.registration.v1.` 独立于一般运行时清理；记录保存到原定／实际时间较晚者之后两天，完整数据清除通过代际隔离失效。AppData、用户备份和通知身份不变。
8. 诊断增加 `registrationDecisions` 与 `duplicatePendingRemoved`，记录原定时间、首次补发时间、ID、状态、抑制原因和移除副本数量；显示状态固定为未知。未决登记被抑制时报告异常，不把它显示为投递成功。

## Windows 队列契约

- 本地历史登记只用于所有权和防重。`pendingPlan`／`pendingMetadata` 必须与原生待发 ID 相交，保留同 ID 副本数量，不再把所有历史记录冒充待发项。
- 调度前预分配并持久化实际 ID，覆盖哈希冲突和写入背景正文前退出的情况。更新前清除受管 ID 的全部待发副本；即使内容没变，也修复未来项的重复副本。
- 只操作确认归属的 ID，不清空整队列，不碰其他 ID 或独立开发测试。每次取消后重新查询，数量没有下降或查询失败即停止，不继续追加。原有近到期恢复保护保留。
- 非 MSIX 已显示卡片可能无法撤回；不为掩盖问题改成静音、延时去抖或应用内定时器。

## 自动验证结果

基线：`5376c91`，版本仍为 `2.3.0+14`。新增 **38 项单元回归**，覆盖录屏序列、固定补发时刻、跨服务／重启、存储失败、结果不明、并发、旧数据迁移、偏移独立性、清理隔离、稍后动作以及 Windows 真实队列语义。

| 检查 | 结果 |
| --- | --- |
| `flutter analyze --no-pub` | 无问题 |
| `flutter test --no-pub --coverage --concurrency=2 --reporter expanded` | **2757 通过，1 项既有 DST 条件跳过**；需专用 CI 设置 `SKED_DST_TEST_ZONE`／`TZ` |
| 现有覆盖率门禁，对比 HEAD | **PASS**；整体 **37769/41604（90.7821%）**，门槛 81.7600%；改动行 **453/483（93.7888%）**，门槛 90% |
| Windows FFI 覆盖边界 | 沿用现有门禁的原生后端排除规则，未降低门槛；另执行真实 Windows 原生队列测试 |
| Windows 非 MSIX 原生队列 | **PASS**：三副本 → 一副本；独立 ID 保留；系统到期取走请求后，恢复和重建 Dart 服务的新增登记数为 0 |

Windows 测试使用独立 AUMID `Mashiro.Sked.NotificationQA`、独立激活 GUID 和测试专用内存偏好，不接触生产日程及通知。该测试确实调用 Windows 原生排程／查询／取消，不是仅用 fake 验证；但重建 Dart 服务不等于测试真实冷进程启动，空的非 MSIX active 列表也不能用来统计横幅。

可重复命令：

```powershell
flutter test --no-pub test/services/agenda_notification_deduplication_test.dart test/services/agenda_notification_registration_store_test.dart test/services/windows_notification_queue_test.dart
flutter test integration_test/notification_queue_native_test.dart -d windows --no-pub --dart-define=SKED_NOTIFICATION_NATIVE_TEST=true
dart run tool/coverage_gate.dart --base-ref HEAD --report .scratch/notification-coverage-final.md
```

原生测试默认不运行；显式启用后可能显示一条“Sked notification QA”测试通知。测试仅清理自己的受管 ID，不调用全局清空。MSIX 构建不能运行这个独立 AUMID 测试，以免借用生产包身份。

本机日志／结果位于忽略目录，不进入发布包：

- `.scratch/notification-final-analyze.log`
- `.scratch/notification-full-final.log`
- `.scratch/notification-coverage-final.md`
- `.scratch/notification-native-windows-final.log`
- `.scratch/notification-native-windows/queue-report.json`（`hasPackageIdentity=false`、`observedBannerCount=null`）

## 尚需人工／设备验收

| 平台／场景 | 当前状态 | 必须记录的证据 |
| --- | --- | --- |
| Android 真机：录屏序列、前后台、点击通知、重启及稍后提醒 | **未执行**；2026-09-15 ADB 列表仍为空 | 按 Android 验收表 N17–N20 记录设备、权限、实际出现／响铃次数及诊断 |
| Windows 非 MSIX：程序持续开启到点、点击通知、唤醒及真实冷启动 | 队列原生验证已完成；**实际横幅次数与真实冷进程路径仍待人工验证** | 同一逻辑提醒实际只弹一次，核对已显示历史与原生排程；不能用登记调用次数替代 |
| Windows MSIX 安装版 | **未执行新版包实机验收**；身份配置及共享逻辑单元回归通过 | 同样执行持续开启、恢复、点击、冷启动，确认可查询／撤回历史的能力没有被误用 |

未把上述待验项目标为通过。未修改通知 UI、依赖或备份格式，未自动提交／推送。
