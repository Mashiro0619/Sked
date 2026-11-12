# Agent Python 执行

Windows 的 `python.execute` 使用应用随包提供的 CPython 3.11。模型可以处理文件、整理数据和生成文档，执行结果包含退出状态、完整输出和已登记的文件。

## 输入与工作位置

调用提供 `code` 和工作目录 `cwd`，按需提供 `argv`、`environment` 及 `inputs`。工作目录使用设备文件工具相同的资源格式；环境变量为字符串键值。

Windows 环境变量名按系统 Unicode 大小写规则比较，同名变量只能提供一次，任务变量覆盖继承值。

`inputs` 的每项包含 `name` 和已有的 `contentId`。准备时读取该会话保存的完整附件，生成供本次执行使用的文件快照。网页正文的第一页或 `content.read` 的分页范围不限制脚本能够读取的文件内容。

脚本通过 `sked_runtime.inputs` 按名称取得这些文件路径。工作目录的真实位置、版本、代码、参数、环境和输入快照一起进入执行预览。

```python
from pathlib import Path
from sked_runtime import inputs, output_dir, publish

source = Path(inputs["material"]).read_text(encoding="utf-8")
result = Path(output_dir) / "notes.txt"
result.write_text(source, encoding="utf-8")
publish(result, name="notes.txt", media_type="text/plain")
print(f"已保存：{result}")
```

`output_dir` 是本次执行的产物目录。`publish(path, name=None, media_type=None)` 登记已经生成的文件，结果保留实际位置和文件版本；脚本也可以使用系统权限允许的其他保存位置。

多个线程或子进程可以同时调用 `publish`；每次登记独立写入并在完整保存后发布，任务中断时继续读取已经发布的记录。

## 审批与停止

计划模式生成执行预览。询问模式等待用户允许后运行；完全权限模式通过原有接纳流程直接运行。准备阶段固定执行材料，实际启动使用同一份代码、环境与输入。

每次执行使用独立进程，派生进程归入同一 Windows Job。用户停止时终止该执行的进程组，等待输出排空和回执保存后结束。标准输出和错误输出完整保存为文件，模型先读取一页，再通过持久内容继续读取。

结果保留退出码、取消状态、输出文件和已登记产物。脚本失败或取消后，已经发生的文件修改仍以实际记录为准。重开后的核对读取原执行记录，不自动重跑脚本。

输出保存失败时保留已经写入的部分，并标明输出不完整。输出内容读取失败时，执行回执保留原结果与文件位置，并单独记录内容交付错误。

## 环境与打包

Windows 构建按 [运行时清单](../tool/python/runtime.json) 准备 CPython，并将解释器和配套脚本放入应用的 `data/python`。依赖在构建阶段固定，用户运行任务时使用随包环境。

权限、持久回执和退出流程见[运行说明](AGENT_RUNTIME.md)，文件内容的保存与续读见[内容说明](AGENT_CONTENT.md)。平台接入进度见[插件架构](AGENT_PLUGIN_ARCHITECTURE.md)。
