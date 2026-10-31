# Android 文件导出

Android 的文本文件和二进制归档都通过系统文档选择器保存。`ExportService.saveBytes` 支持 ZIP 等原始字节内容，调用方继续提供文件名、字节和 MIME 类型；不需要将归档转成文本或 base64。

二进制导出先由原生端在应用私有缓存中创建一次性目录和源文件。Dart 完整写入并关闭文件后，只提交本次准备令牌；原生通道不接受调用方指定的源路径。选择目标之前检查准备文件与声明长度，随后在工作线程中以 64 KiB 缓冲区复制到系统提供的目标流，并再次核对实际字节数。用户选择的文件名不参与源路径构造。

准备、选择目标和复制共用单个导出名额。已存在导出时，新的文本或二进制保存返回失败，不替换前一个请求。迟到的选择器结果或旧令牌不能完成、读取或删除新请求的源文件。

只有目标流写入、刷新和关闭完成且准备文件清理成功，才返回 `saved`。取消文件选择返回 `cancelled`；拒绝访问、缺少文档提供方和其他失败分别保留对应结果。复制过程中不生成估算百分比。Android 返回的 `path` 沿用建议导出名称，不是系统提供方的绝对文件路径。

成功、取消或失败后删除本次源文件和空目录；Dart 的 `finally` 也按同一令牌释放准备，用于处理本地写入失败。清理不会递归删除目录中的未知文件。Activity 或 Flutter engine 结束时，尚未开始的导出取消；已经接受的复制先观察取消并关闭流，再清理源文件，不把仍在进行的复制报告为完成。系统强杀不属于已完成或已确认取消。

系统文档提供方不提供通用文件事务。目标写入失败可能留下部分目标文件，导出流程不声称已回滚或删除该文件；本机原始数据不作为流复制的源文件。

回归入口为 [Dart 导出服务](../test/services/export_service_test.dart)、[原生缓存与令牌](../android/app/src/test/kotlin/com/mashiro/sked/BinaryExportStagingTest.kt)、[流复制](../android/app/src/test/kotlin/com/mashiro/sked/ExportStreamCopyTest.kt) 和 [平台请求生命周期](../android/app/src/test/kotlin/com/mashiro/sked/PendingActivityRequestTest.kt)。这些检查覆盖模拟通道及 JVM 文件/流行为；真实 Android 文档提供方、Activity 回收与设备存储权限仍按实际设备分别验收。
