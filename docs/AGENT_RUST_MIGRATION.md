# Agent Rust 重构与依赖整理

执行基线：`c8edd681`。本次只迁移 Agent 核心，Flutter 界面、课表日程、导入导出及平台功能继续由 Dart 维护。

## 已确定的方案

- Rust、Rig 和 flutter_rust_bridge 在设备本地运行，使用现有连接配置调用模型 API。
- 完整接通问答、计划、队列、压缩、历史编辑重做、知识、附件、标题、用量和备份后切换正式装配。
- Agent 尚未发布，直接重建聊天、附件、自定义 Skills 和记忆开发数据；删除旧 Agent 格式判断和迁移分支。业务数据、连接及密钥保留。
- Windows、Android 完整接入；其他端保留编译和普通功能，未接通的 Agent 明确显示暂不可用。
- 先完成离线验收；真实模型调用和性能对照继续暂停。

## 所有权与接口

Rust 拥有模型及工具循环、运行取消、会话与交互状态、上下文、知识、Agent 存储和结果投影。Dart 业务宿主拥有课表日程规则、领域校验、业务保存与回执、业务撤销、导入导出、通知、学校网页及设备动作。系统安全存储继续保管凭据。

桥接使用类型化的 `initialize`、`dispatch`、`query`、`watchEvents`、`submitHostResult`、`shutdown`。Flutter 用 `RustAgentUiDelegate` 连接现有界面。命令和事件覆盖已有行为，只有动态工具参数、schema 和服务协议材料使用 JSON。

每个会话保持一份执行对象；离开聊天页面只取消页面订阅。停止请求立即反馈，已接纳的业务保存完成后才开放继续。普通运行不设置 Token、模型轮数、工具次数或时限配额。

工具定义、参数和使用说明同源；发现状态随会话恢复。模型仍用一次业务工具调用完成一次操作。结果区分模型摘要与界面完整详情，参数错误指明字段。审批仅允许／拒绝，保留计划、确认和完全权限模式。

## 存储

| 内容 | 存储 |
| --- | --- |
| 消息、工具调用与结果、运行、队列、问答、摘要、历史版本及操作绑定 | 每会话一个追加式 JSONL |
| 会话列表、消息位置、分页和查询索引 | `conversation-index.sqlite`，可重建 |
| Skills、记忆、知识版本及撤销记录 | `knowledge.sqlite`，正式知识数据 |
| 图片与其他附件 | 私有文件，JSONL 保存引用 |

每个会话由 Rust 顺序写入，一次关联状态变化保存成一条完整记录。流式文字用于实时显示，完整消息结束后保存；草稿沿用原保存节奏。编辑、重做和重新生成追加版本记录。索引不重复保存聊天全文。

Agent 备份只实现新布局的导入导出；业务备份仍由现有 Dart 实现负责。

## 依赖基线

Rust 1.97.1；Rig 0.46.0（agent、reqwest、rustls）；FRB 的 Dart／Rust／codegen 统一 2.13.0；Tokio 1.54.1；tokio-util 0.7.20；rusqlite 0.41.1（bundled）。SQLite 由专属工作线程处理。

Flutter 3.47.7／Dart 3.13.5 和现有 Android 工具链保持。新增 Cargo.lock。

分批更新 crypto 3.0.8、web 1.1.2、lunar 1.7.9；material_ui 1.10.0、cupertino_ui 1.1.6；flutter_local_notifications 22.3.3。archive 保持 4.5.2，WebView 保留三个固定 Git 补丁。依赖声明与锁文件一起维护。

Rust 存储切换后删除 drift、drift_dev、build_runner、Agent 数据库生成代码及专用 Web worker／Wasm 资产。http、crypto、html、archive、Markdown 和平台依赖仍被保留的功能使用。

## 实施进度

| 阶段 | 完成条件 | 状态 |
| --- | --- | --- |
| 1. 基线和依赖 | 三批依赖更新，相关分析、编译和功能检查 | 依赖更新已提交，原生构建随接入阶段验证 |
| 2. Rust 与 FRB | Windows／Android 加载 Rust，命令、事件和宿主回调接通 | 两端正式离线旅程已通过，Android 系统证书初始化已接通 |
| 3. 新存储 | JSONL、索引、知识、附件和新备份完整可用 | Rust 存储已实现，待接入正式会话仓储与综合备份 |
| 4. Rig 与业务工具 | 离线模型回包驱动正式工具并取得真实业务结果 | 正式业务宿主的三种权限与保存收尾已通过离线旅程，平台等其余适配待接线 |
| 5. 完整功能 | 现有 Agent 功能全部接入原界面 | UI delegate 已实现，完整页面、知识与附件管理仍待接线 |
| 6. 切换清理 | 等已接纳动作完成，重建开发数据，删除旧实现 | 待开始 |
| 7. 离线收尾 | 两端安装包、完整功能旅程和文档完成 | 待开始 |

接入阶段通过离线演示入口逐步完成，完整功能接通后切换；最终不保留旧 Dart harness 回退执行路径。

## 当前接入入口

`rust/src/api` 提供生成桥接，`AgentRustClient` 等待原生事件订阅就绪后开放命令。停止或退出先关闭新请求入口，宿主仍可提交已接纳保存的最终回执；重复退出调用等待同一收尾过程。

`RustAgentBusinessHost` 为每次运行持有业务作用域，复用 `ApplicationToolHost` 和 `MutationCoordinator`。准备记录持久化后才进入业务保存；待审批对象建立后才发布允许／拒绝入口。历史主库撤销通过 `RustAgentMainUndo` 读取原始回执并复用领域撤销入口。

`RustAgentUiDelegate` 消费原生会话及运行投影，当前上下文计量、压缩状态、重生成目标与实际活动状态均来自 Rust。立即补充交接期间保持运行状态，旧保存收尾之后才开放继续。页面释放订阅不关闭核心。

原生入口为 `integration_test/agent_rust_offline_journey_test.dart`：模型使用预置回包，FRB、Rust 核心、业务工具、主库文件和 JSONL 使用正式实现。流程覆盖工具发现、三种权限、流式回复、已接纳保存期间的页面关闭、排队、停止继续、退出及重新打开数据。

Rust 工具链版本与目标维护在 `rust/rust-toolchain.toml`；手动 Cargo 命令从 `rust/` 目录运行。Flutter native assets hook 使用同一工具链，Android 编译使用项目当前最低 API，不提升 Android 基线。Android 的 `SkedApplication` 在启动时加载原生库并初始化系统证书验证器，AAR 版本取自 `Cargo.lock` 中的配套发布版本。正式 `AgentApplication` 仍使用现有装配，待全部功能接通后统一切换。

## 验收与提交

离线模型替身只替换模型回包，Rust、FRB、Dart 业务保存及本地存储使用正式实现。完整旅程包括：新会话及附件；查询／创建／批量／重复实例修改、参数纠错和三种权限；问答、计划、队列、补充和停止继续；压缩、模型切换、重生成及历史重做；知识与附件管理、备份恢复、删除清空。

检查 Windows 普通／Store MSIX 和 Android APK／AAB，保留当前界面布局。使用编译、静态检查、现有功能回归和实际离线操作，不增加防御性测试矩阵，不机械移植旧实现内部测试。

Rust 工具链、缓存、临时工作副本、构建、日志和演示数据放 F 盘。开发在 main 分阶段进行，保留既有未提交改动；每个原子提交使用中文消息、SSH 签名并验签。每阶段同步当前行为文档。
