# 设备偏好快照接口

`DesktopLayoutPreferences` 保存用户明确设置的面板尺寸；`DeveloperUiPreferences` 保存旧开发者预览偏好。两者使用各自的 SharedPreferences 键，与 AppData 和旧整体 JSON 的格式保持分离。

本层提供偏好快照和受控恢复接口。页面入口、备份选择和跨库恢复协调器的接线由后续改动完成。

## 快照格式

`PortableDevicePreferences` 为每个配置组记录格式版本、来源平台、组名及值。平台区分 Android、iOS、Windows、macOS、Linux、Web 和 Fuchsia；稳定身份由平台与组名组成。

`desktopLayout` 只接受已知呈现区域的有限正尺寸。`developerUi` 只接受布尔值或表示未设置的空值。读取拒绝未知字段、区域、平台、组及格式版本；快照不接受文件路径、原生权限、窗口句柄、凭据或运行状态。尺寸区域列表与实际枚举通过回归共同约束。

## 拥有者与恢复边界

`DevicePreferencesStore` 汇合两个真实偏好服务。调用方可在使用前通过 `bindServices` 绑定界面已有的拥有者；被借用的服务仍由原拥有者管理生命周期。存储冻结期间不能替换绑定。

调用方先取得应用维护权，再调用 `freezeAndDrain`。该方法同步阻止两个服务接受新的用户修改，然后排空已接受的读写和尺寸保存。未确认的保存失败会返回错误，调用方应保留错误与原恢复意图。

`readGroup` 从实际持久层重读一组值。`restoreGroup` 要求冻结状态和调用方的有效拥有权，写入指定组后重新读取并核对；存储回调返回成功不能代替目标读回。未指定组不会写入，空尺寸组和未设置的预览值只删除各自的偏好键。

冻结期间读回的内容同步给原界面服务。接受的写入与目标核对结束后，由调用方执行 `resume` 重新开放普通修改。跨组恢复需要由上层保存各组原值和目标，并分别核对持久状态；单次写入失败也可能已经留下目标值，重试前应先重读。

## 验证范围

[独立恢复回归](../test/services/device_preferences_restore_test.dart)覆盖严格格式、共同冻结与排空、同一界面拥有者、组间保留、写入与回执不一致、持久读回、重开及显式默认值恢复；原有[面板偏好](../test/services/desktop_layout_preferences_test.dart)和[开发者偏好](../test/services/developer_ui_preferences_test.dart)继续覆盖日常保存与生命周期。

这些回归使用 Flutter VM、内存故障替身和 SharedPreferences 插件模拟存储。原生插件、浏览器和实体设备的验收需要分别记录。
