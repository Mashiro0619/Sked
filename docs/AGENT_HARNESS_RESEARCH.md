# Sked agent harness 源码研究

研究日期：2026-10-29（Asia/Shanghai）。Sked 基线：`main`，`ea784f3a16e5d4a23aedae410544492fb6fa0f6f`。本报告只做联网检索、源码下载和静态阅读，没有运行第三方安装脚本、harness、模型调用、Sked 测试或构建。当前主分支是移动目标，下面按实际下载的 SHA 固定证据；这里不宣称它们是稳定发行版。

## 结论

Sked 的产品边界为一个跨平台内置 Agent、多个会话，支持用户自选 API。功能管理提供这一 Agent 的启用/显示开关，手机端使用独立完整页面。所有会话共享内置 Agent 的工具与 Skills；模型连接属于配置。权限模式仅有只读计划、每次修改前询问、完全权限三种，由用户选择。

现有独立网页/文字 AI 解析统一迁入会话：文字直接输入，网页保留本地压缩和校对后新建会话；旧专用解析设置和网络链路退役。按[共享 Skills 设计](AGENT_SKILLS.md)封装任务技能、按需发现加载，不为每个会话创建私有技能。具体迁移和来源交接见[架构](AGENT_ARCHITECTURE.md)及[实施计划](AGENT_IMPLEMENTATION_PLAN.md)。

推荐 Sked 自有的 Dart 应用命令层 + 小型、可替换 agent runtime。完整 UI 和 Agent 应共用业务命令，不让 harness 直接编辑 JSON 文件或模拟点按 UI。pi/DeepSeek/Codex 的进程桥接可作为后续桌面集成研究，通过相同命令接口访问 Sked；这些运行时实现选择不增加独立 Agent 定义或管理功能。

三种层次要区分：模型提供推理和工具请求；harness 管理循环、上下文、工具执行、取消、会话恢复；Sked 领域层负责真实修改、验证、保存、撤销和平台副作用。MCP/JSON-RPC 只是可选连接协议，不能替代另外两层。

本次最值得直接吸收的设计：

- pi 的简洁 loop 与 provider 边界，以及 `steer` / `followUp` 两类队列语义。
- 新增、仍处实验阶段的 pi-durable：工具执行前记录 intent；明确 safe/unsafe replay；已提交状态与 UI 事件同步。
- DeepSeek 的可替换工具执行器、明确默认串行的业务副作用边界、带类型的 canonical result 与 UI projection、插件生命周期、持久 inbox、未知副作用状态的保守恢复。
- Codex 的 Thread/Turn/Item 事件模型、宿主接管动态工具执行、工具暴露与取消路由。它能作为产品内 agent 的进程后端，但应用仍拥有业务数据与写入约束。
- OpenCode 的操作/资源识别、执行前检查和 host/client 拆分。这里的 OpenCode 已进入新的包结构，旧 `packages/opencode/src/session/processor.ts` 路径不适用于本次快照。

## 已核实仓库、版本与许可

| 对象 | 实际来源与 SHA | 许可、运行时 | 对 Sked 的适配判断 |
| --- | --- | --- | --- |
| Codex CLI / app-server | `openai/codex`；`2681f8cba2831ef72bca2c0672b2e49d5f690745` | Apache-2.0；Rust 核心与 TypeScript SDK；本次只读取固定版本源码 | 适合借鉴宿主/agent 分工，或可选桌面进程桥接；没有本次验证的全 Flutter 平台嵌入方案 |
| pi（旧称 badlogic/pi-mono） | GitHub 的旧地址实际重定向到 `earendil-works/pi`；`e7a0df27c09d11bf4161d3605246cbf57a129cb2` | MIT；根 package 要求 Node >=22.19；包改为 `@earendil-works/*` | agent-core 思路最容易移植；SDK 直接用于 Node/Bun，Dart 需要桥接或自己的实现 |
| DeepSeek Harness | 官方 DeepSeek 网站链接 `deepseek-ai/deepseek-harness`；`f3803c96974ad4a94195fb97e5c637e9c2a3afe3` | MIT；根 package `0.2.2-alpha.2`，Node >=24.9；官方明确 developer preview、会有破坏兼容变更 | 可组合性和恢复边界值得学习；直接整包嵌入 Flutter 不合适，桌面子进程可行性较高 |
| OpenCode | `anomalyco/opencode` 的 `dev`；`87a35fa43ac51ecb89ddafdb8dad07f79e967c43` | 本次读取 LICENSE 为 MIT；源码为 TS/Effect、Node host 分层 | 可研究权限和客户端协议；本次只定点下载相关模块，没有完整审核其 agent loop |

官方身份来源：[DeepSeek 官方产品页](https://www.deepseek.com/en/harness/)、[DeepSeek 官方仓库](https://github.com/deepseek-ai/deepseek-harness)、[pi 原仓库重定向](https://github.com/badlogic/pi-mono)、[pi 当前仓库](https://github.com/earendil-works/pi)。搜索中存在镜像和第三方 “DeepSeek Harness” 域名，结论只取官方站与源码。这里的 DeepSeek Harness 是已核验的官方开源项目，与 DeepSeek 模型 API 分别讨论。

许可核对：[Codex LICENSE](https://github.com/openai/codex/blob/2681f8cba2831ef72bca2c0672b2e49d5f690745/LICENSE)、[pi LICENSE](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/LICENSE)、[DeepSeek LICENSE](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/LICENSE)、[OpenCode LICENSE](https://github.com/anomalyco/opencode/blob/87a35fa43ac51ecb89ddafdb8dad07f79e967c43/LICENSE)。如果复制或移植源码，按相应许可保留版权、许可与适用 NOTICE，标明修改；依赖许可需在真正选用时按所选包核对，不能由根许可推断所有依赖都相同。

## Codex：产品宿主保留数据和控制权

官方文档：[Codex as a platform](https://developers.openai.com/blog/codex-as-a-platform)、[Codex App Server](https://learn.chatgpt.com/docs/app-server)。两者均在本次研究实际打开。官方区分一次性 `codex exec`、程序化 SDK 与产品内 app-server；harness 管循环、会话和工具交互，应用拥有界面、业务记录、授权与真实动作。

- app-server 使用 Thread/Turn/Item；stdio 是默认双向 JSONL RPC，提供会话恢复、事件流、`turn/steer` 与 `turn/interrupt`。宿主需持续消费完成状态，不能只等待请求被接受。
- `dynamicTools` 与 `item/tool/call` 是实验 API；官方同时将 WebSocket transport 标为 experimental/unsupported。若做可选桌面适配，应固定二进制和生成的 schema，先采用 stdio；远程部署另行处理鉴权和 TLS。此处不承诺生产兼容性或移动端运行。

定点源码：[dynamic.rs](https://github.com/openai/codex/blob/2681f8cba2831ef72bca2c0672b2e49d5f690745/codex-rs/core/src/tools/handlers/dynamic.rs)、[router.rs](https://github.com/openai/codex/blob/2681f8cba2831ef72bca2c0672b2e49d5f690745/codex-rs/core/src/tools/router.rs)、[registry.rs](https://github.com/openai/codex/blob/2681f8cba2831ef72bca2c0672b2e49d5f690745/codex-rs/core/src/tools/registry.rs)、[TypeScript thread.ts](https://github.com/openai/codex/blob/2681f8cba2831ef72bca2c0672b2e49d5f690745/sdk/typescript/src/thread.ts)。

- `dynamic.rs:95–98` 的 handler 支持并行调用；`:128` 起解析模型参数，再通过动态工具请求等宿主返回结果，携带 CancellationToken。Sked 适配层必须自行串行化写入，不能因 harness 支持并发便并发写整个 AppData。
- router 将工具名、payload 与取消 token 送入 registry；registry 区分 Direct、Deferred、Hidden 等暴露策略以及执行器。可借鉴能力按需发现，避免一次将所有设置字段塞进 prompt。
- `thread.ts:78` 起的 `runStreamedInternal` 通过 CodexExec 运行，携带 thread ID、模型、signal、sandbox 与 approval 参数，读取 thread/turn 事件；`run()` 收集完成 items 和 usage，turn.failed 会抛错。它是包装已有执行进程的 SDK，不是无需宿主运行时的 Dart agent 库。
- 动态工具结果的 `success` 只反映宿主回执。Sked 必须在真正持久化后返回成功，并返回 commandId/revision 供恢复核验；harness 无法替宿主证明磁盘和通知副作用已完成。

本次未完整克隆或运行 Codex。上述比较以固定 SHA 的几个关键源码与官方协议文档为限，不把外部文档中新的实验能力当作 Sked 已支持的能力。

## pi：核心循环、SDK 与实验性 durable 是不同选择

### agent-core

源码：[agent-loop.ts](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/packages/agent/src/agent-loop.ts)、[agent.ts](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/packages/agent/src/agent.ts)、[types.ts](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/packages/agent/src/types.ts)。

- `agent-loop.ts:179` 起是外层 follow-up 与内层 model/tools 的循环；每轮可 `prepareNextTurn`、`prepareRequest`，转换模型输入只发生在边界。
- `agent-loop.ts:254`，模型 error/aborted 立即收尾；`:277` 对 token limit 截断的 tool call 整批返回错误，避免执行残缺参数。
- `:518` 选择 sequential/parallel；单个工具可要求 sequential。`:737` 参数 schema 验证后才进入 `beforeToolCall`；允许宿主阻止执行；`afterToolCall` 能统一脱敏或变更结果。
- `agent.ts:308` 的 `steer` 影响下一轮，`:313` 的 followUp 等当前工作自然停下；`:350` abort 发取消信号，`:359` waitForIdle 等结束。仅发 abort 不能撤销已经落盘的业务修改。
- `types.ts` 把 model output、tool result、UI details、typed errors 区分开。此种边界比直接输出模型文字更适合 Sked 的“已修改 12 个日程”结果卡。

provider 层独立：[models.ts](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/packages/ai/src/models.ts)。`Provider`（158）、`Models`（258）、`MutableModels.setProvider`（369）、`streamSimple`（929）等使运行时不绑单个模型。Sked 可对应设计 `ModelProvider` 接口，先支持真正需要的 1–2 种 wire protocol，再逐步扩展；不应为接入模型先导入 coding-agent 全部文件工具。

### coding-agent SDK / CLI RPC

源码与文档：[SDK](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/packages/coding-agent/docs/sdk.md)、[CLI integration](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/packages/coding-agent/docs/cli-integration.md)、[session-manager.ts](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/packages/coding-agent/src/core/session-manager.ts)。

- SDK 是 Node/Bun 进程内 TS 集成；`createAgentSession` 可替换 model、tools、resourceLoader、settingsManager、sessionManager。
- SessionManager 用 JSONL entry tree；branch 移动 active leaf，不删除弃用分支；compaction 是单独 entry，重新生成上下文。它不是 Sked 数据库的事务管理器。
- long-lived RPC 使用 stdin/stdout JSONL，可让 Dart 桌面端启动进程并发出 prompt/steer/abort。`prompt` 的成功响应只表示接受，UI 应等 `agent_settled`，不能看到 `agent_end` 就宣称整个自动恢复/排队工作完成。
- SDK 默认会发现 cwd 下资源和工具；若 Sked 采用，必须显式提供自己的资源加载器和工具集。不能把默认任意文件、bash 能力等同“能配置全部 Sked”。
- 根 README 明确没有内置限制文件/进程/网络/凭据的 permission system。扩展能拦工具，但可信代码本身仍有进程权限。因此适合扩展机制和纯内核，不应依赖它替 Sked 实现资源权限。

### pi-durable（目前 experimental）

源码：[tool.ts](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/packages/durable/src/harness/tool.ts#L129)、[durable README](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/packages/durable/README.md)、[storage failure tests](https://github.com/earendil-works/pi/blob/e7a0df27c09d11bf4161d3605246cbf57a129cb2/packages/durable/test/harness-storage-failure.test.ts)。

这是新的独立 durable harness，不等同传统 agent-core 加一个 JSONL 文件：

- `tool.ts:129–212`：校验参数、执行 hook 后再次校验，先 commit 最终参数和 `replay` intent，再调用工具；恢复时历史与当前工具都声明 safe 才重放，否则产生 interrupted/可能部分执行结果。
- default replay 是 unsafe。即使 safe 模式，外部副作用也需要业务自己的幂等键；不能把 runtime 的 retry 当 exactly-once。
- 提供对话、任务、提交、持久 sleep/重试、工具子任务；SQLite、JSONL、IndexedDB 等 storage adapter。停止等待与取消任务分开。
- 结果有面向模型的 `output`、程序用 `structuredOutput`、UI 用 `details`；输出 schema 也会验证。
- `harness-storage-failure.test.ts` 检查存储故障会终止正在执行的任务和 watch、后续提交拒绝。只是已读测试源码，本次未运行。
- README 首行明确 API 可不预告变化；对 Sked 首版适合吸收恢复契约，若直接集成必须锁版本、建立 own adapter，并避免把实验 API 蔓延到全部 UI。

## DeepSeek Harness：插件组合、执行器和恢复契约

### 循环与持久队列

源码：[agent.ts](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/core/agent-loop/src/agent.ts)、[inbox.ts](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/core/agent-loop/src/inbox.ts)、[native executor](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/core/tool-executor-native/src/index.ts)。

- public Agent contract 与默认 loop 分包。loop 驱动 model→tools→model，可替换 executor；调用模型前解析本轮 tools 和 model selection。
- `agent.ts:170–196`：followup 到 next-turn、steer 到 next-step、inject 不主动唤醒；cancel 可以清掉 inbox 或 keepInbox，后续输入不会插入已经取消的活动。
- `inbox.ts:25–61`：队列是 session event 的 projection，splice 有边界检查与 message ID 去重，重启可重建待处理消息。比只保存聊天记录完整。
- `agent.ts:490–608`：stream 部分响应在取消时记录为 interrupted；max-tokens 不执行工具；工具批次的 partial additionalContexts 保留；下个步骤重新决定输入。

### 工具、策略、并发

源码：[contracts.ts](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/core/tools/src/contracts.ts)、[pipeline.ts](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/core/tools/src/pipeline.ts)、[batch.ts](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/core/tools/src/batch.ts)。

- ToolDefinition 有强制 output JSON schema；工具返回 canonical JSON，render/presentCall/presentResult 负责模型与 UI 展示。重播 UI 时不用重跑工具。
- `contracts.ts:72` 起的 `isConcurrencySafe` 是 opt-in；缺失、异常、非 true、参数非法都 exclusive。只读独立查询可并行；Sked 写操作先串行，这比直接照抄“最多 10 个并行工具”可靠。
- pipeline 有 pre-execute guard、around execute、post-execute；取消不能让已启动的同进程 Promise 悬空，需等自有工作收敛，但无法强杀不合作的同进程代码。
- 支持 Native 与 PTC/programmatic executor。Sked 首版只需要 Native 工具调用；不是为了 agent 就必须开放可执行 JS、任意 shell、第三方插件安装。
- [user-approval service](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/interaction/user-approval/src/index.ts) 定义 ask/never，按动作请求、取消、审计；never 的语义是拒绝“需要审批”的动作，不是自动放行。Sked 借鉴执行前校验与审计机制，产品权限按只读计划、每次修改前询问、完全权限三种模式实现。
- `guard/` 包家族本身是重复工具提醒和超时策略，不能误写成它已提供 Sked 资源权限系统。

### 会话、持久化和失败恢复

源码：[session service](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/core/session/src/index.ts#L1329)、[repair.ts](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/core/session/src/repair.ts)、[checkpoint policy](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/session/session-checkpoint-policy/src/index.ts)、[compaction](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/compaction/compaction/src/index.ts)。

- session append-only log 与当前 model transcript 分开。compaction 是替换 active surface，不删除原始历史。
- core session 默认是内存，持久化由插件提供；`flush()` 等所有 persistence listener 结束并抛错误，返回是否存在 listener。因此只“用了 Session”不代表持久。
- 配合 session-checkpoint-policy 时，模型请求前、顶层工具 body 前和下一步边界会 flush；flush 失败不会继续调用模型或工具。该策略是显式组合的插件，不能仅凭 loop 包名假设已启用。
- batch 记录 tool/call 和 tool/result；`repair.ts` 依据历史中是否出现 tool/call 区分 `TOOL_NOT_STARTED` 与 `TOOL_OUTCOME_UNKNOWN`。已开始但未记录结果的操作不能盲重试，要以领域幂等或外部状态核验解决。
- 日志 durable 不等于 Sked mutation 与日志原子提交。仍需自己的 commandId、expected revision、change set、事务回执与恢复查询。
- 已阅读取消测试 [cancel.spec.ts](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/core/agent-loop/tests/cancel.spec.ts)、[persistence live-write tests](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/session/session-persistence/tests/live-write-contract.ts)。可以借其测试场景，不能当作 Sked 已验收。

### provider 与嵌入

源码：[llm-pi-ai adapter](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/llm/llm-pi-ai/src/index.ts)、[SDK client](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/sdk/client/src/index.ts)、[SDK package map](https://github.com/deepseek-ai/deepseek-harness/blob/f3803c96974ad4a94195fb97e5c637e9c2a3afe3/packages/sdk/README.md)。

- provider-neutral llm service，可通过 DeepSeek provider 与 pi-ai adapter 注册其他 provider/custom gateway；所以 “采用 DeepSeek harness” 不必等于 “仅 DeepSeek 模型”。
- TS/Python SDK 启动同版本 `dsh --profile sdk`，经 stdio JSON-RPC 驱动完整运行时；不是纯 Python agent loop，也不是 Dart SDK。
- Cordis 的工具、会话、模型、设置、UI、sandbox、subagent 都是可生命周期管理的插件；可从 minimal profile 选择依赖。不必完整照搬桌面 UI。
- 对 Windows 桌面可探索子进程；Android/iOS/Web 没有本次可证实的直接嵌入保证，本次未测试这些平台。Flutter 首版若强依赖 Node 子进程，会增加打包、跨进程恢复与后台限制，不宜成为全平台基底。

## OpenCode：补充比较（定点读取）

来源：[permission.ts](https://github.com/anomalyco/opencode/blob/87a35fa43ac51ecb89ddafdb8dad07f79e967c43/packages/core/src/permission.ts)、[server/routes.ts](https://github.com/anomalyco/opencode/blob/87a35fa43ac51ecb89ddafdb8dad07f79e967c43/packages/server/src/routes.ts)、[compaction.ts](https://github.com/anomalyco/opencode/blob/87a35fa43ac51ecb89ddafdb8dad07f79e967c43/packages/core/src/session/compaction.ts)。

- permission 使用 action/resource 通配规则、最后匹配规则优先，allow/deny/ask；结合 agent 和 project 规则及保存的允许项。Sked 可借鉴操作与目标资源的准确识别，界面只提供既定三种权限模式。
- server 构造 API、鉴权、CORS、session、Job、Schedule、MCP、credential 等服务；适合学习 host 与 UI 的边界。不能因有 HTTP 服务就把 Sked 私人数据接口绑定公开地址。
- compaction 区分自动、overflow、手动输入、后台 summary 等触发，值得参考上下文预算；首版无需复制其复杂策略。
- 此部分只核验相关 5 个文件和仓库树，未声称已研究其完整 SDK、provider 与 loop 行为。

## 对 Sked 的具体建议

### runtime 最小契约

以概念接口表述，不宣称已有代码：

1. 单例 `AgentSettings`：内置 Agent 的启用/显示开关、公共 instructions、模型连接配置引用、三选一的权限模式和运行预算。模型连接可配置，工具与 Skills 由这一内置 Agent 共享。
2. `Conversation` / `Thread`：同一 Agent 下的会话，保存 messages、inputQueue、run 状态、简洁 summary 与工具回执索引；支持新建、切换、重命名和删除会话。历史记录保留每次运行使用的配置版本，恢复时以用户当前选择的权限模式控制后续操作。手机端在独立完整页面组织会话与执行过程。
3. `ModelProvider.stream(request)`：统一 text/tool-call/usage/error/finish 事件；仅完整 tool-call 才执行；支持 abort、超时、有限重试。
4. `ToolRegistry`：稳定 name+version、输入/输出 schema、操作类型、目标资源、并发属性、执行函数与 result UI。模型只能调用本次明确暴露的工具。
5. `CommandGateway`：查询、校验/预览 change set、应用、按 commandId 获取结果、撤销。所有手工 UI 与 agent 写入最终走同一层。
6. `RunJournal`：accepted→validated→executing→committed/failed/cancelled/unknown；记录 conversationId、配置版本、权限模式、询问模式下的确认回执、domain revision 和 effect 状态，不将“模型说完成”视为保存成功。

### “全部可配置”的正确实现方式

覆盖所有课表、日程、设置及其他可配置项的业务操作。宿主按用户选择的以下三种模式执行，不增加自动模式或自定义 allow/ask/deny 范围配置界面：

| 权限模式 | 执行语义 |
| --- | --- |
| 只读计划 | 查询、解释与生成修改计划；不执行业务数据或设置的新增、修改、删除。会话历史与运行日志可正常保存。 |
| 每次修改前询问 | 每次真实修改前展示准确目标和变更并等待确认。具备原子提交保证且整体展示的批量操作可确认一次；变更内容、目标或依赖版本改变后重新确认。 |
| 完全权限 | 允许在全软件范围内连续执行新增、修改、删除和配置操作，无需应用级逐次审批；包括批量删除、恢复与凭据配置等受支持操作。 |

- 三种模式使用同一套工具、严格数据校验和持久化契约；执行后的真实回执、撤销能力与变更历史不因完全权限而省略。
- 读取 API key 只返回连接状态/掩码，替换或删除凭据是受支持操作；模型不需要得到密钥原文。
- OS permission/native dialog 仍由平台处理，完全权限不能代替系统授权；需要用户完成的系统动作应明确返回待处理状态。
- 权限模式由用户在宿主界面选择。Agent 不能通过普通 `settings.patch` 将只读计划或询问模式提升为完全权限，也不能改写确认回执。

### 单写入者与重试

1. 查询在 snapshot/revision 上完成；修改命令携带 expected revision，遇冲突返回新差异重算，不能静默覆盖同时发生的 UI 修改。
2. commandId 在业务层稳定，保存回执与数据提交有可恢复关联。若网络或模型重试，返回原结果而不重复创建日程。
3. undo 用语义逆操作或版本快照，检查之后的变更，不盲目回滚整份用户数据库。
4. 取消只中止未开始步骤；正在提交者等待真实结果，已提交步骤展示 partial completion。通知等已实现的副作用用可重试 outbox/desired-state reconciliation；未来新增小组件时再接入对应效果。
5. 所有 runtime 不论自研或外接都经过同一 policy 和 command gateway。外接 harness 不能直写数据文件来绕过。

### 集成路线取舍

| 方案 | 优点 | 成本/限制 | 建议 |
| --- | --- | --- | --- |
| Dart 自有轻量 runtime + 领域工具 | 所有 Flutter 平台共用契约；UI/保存/取消边界最清楚；无需独立 Node | 需自己实现流式 provider、队列、持久化和 eval | 首版基底 |
| pi core / durable TS sidecar | provider 和 agent loop 可直接复用；桌面试验快 | Node 打包、Dart RPC、平台覆盖；durable API 实验性 | 桌面对照 PoC，可插拔后端 |
| DeepSeek minimal profile sidecar | 丰富插件组合、队列、工具展示与恢复能力 | Node >=24.9、rapid preview 兼容性、较大维护面 | 高级桌面扩展或独立服务对照 |
| Codex app-server sidecar | 持续会话、事件与动态工具交给宿主；Rust 进程边界 | 动态工具协议实验性；二进制、schema 与工具权限适配 | 可选桌面对照，不能成为手机端必需 |
| 云端运行 harness | 移动客户端轻、可以持续后台任务 | 本地优先数据同步、设备在线、隐私、服务器成本和授权链 | 明确有跨设备后台需求再增加 |

### 建议的对照 PoC 与验收题目

不要只测聊天是否能回复。使用纯合成数据，对所有候选调用同一业务工具：读取两个课表→按自然语言约束移动课程→解决冲突→新建复习日程→关闭对应提醒；检查最终 domain state、保存回执与展示一致。

必须包括：请求重试重复创建；模型输出参数截断；未知工具/字段；UI 同时修改 revision 冲突；工具开始前/保存中/保存后取消；数据已提交但 run 日志未完成时重启；日程跨时区/重复实例编辑；持久化失败；通知平台副作用失败；inbox 队列重启；多个会话切换与恢复保持正确历史；长对话 compaction 后仍遵守用户当前权限模式；只读计划不产生业务修改；询问模式未确认不执行且原子批可整体确认一次；完全权限连续操作不出现应用级逐次审批；导入文本中的 prompt injection 不改变权限；不存在的 OS 权限不能伪造成功。测量工具成功率、真实任务完成率、工具轮数、请求成本、token、冷启动、响应延迟、崩溃恢复重复写入次数（目标 0）。

## 研究证据与局限

核验平台为 Windows。可复查命令为 `gh api repos/<owner>/<repo>/commits/<ref>`、`git clone --depth 1 <url>`、`git rev-parse HEAD`、`rg` 与固定 SHA 源码读取。pi/DeepSeek 使用完整浅克隆，OpenCode 为固定 SHA 的五个定点文件，Codex 为固定 SHA 的工具路由、动态工具、SDK 等定点源码与官方文档。原始下载和一次性记录留在系统临时目录。下载和源码读通不代表 harness 可在本机运行，也不代表跨平台验收。本文为设计研究，功能尚未集成。
