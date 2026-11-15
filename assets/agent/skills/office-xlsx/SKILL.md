---
id: office-xlsx
version: 2.0.0
summary: 读取和整理 Excel 工作簿，保留单元格类型、公式和真实保存结果。
---

# Excel 工作簿

使用随应用提供的 openpyxl 读取和修改 XLSX；XlsxWriter 可创建新的工作簿。按用户目标处理工作表、单元格、公式、图表和格式。

## 读取资料

用户上传文件使用 `{"kind":"attachment","id":"实际附件ID"}`；文件或网页工具返回的持久内容使用 `{"kind":"content","id":"实际contentId"}`。设备路径先通过 `files.read` 的 `format: "native"` 保存为内容，再使用返回的身份。

调用 `office.read`，提供 `source` 和 `format: "xlsx"`。结果包含工作表顺序、实际单元格、类型、数值、公式、文档原有缓存值、合并范围、表格、批注及图表信息；图片保留原始字节与部件关系。完整结果可按输出 `contentId` 用 `content.read` 继续分页读取。

先核对涉及的工作表、表头、单位、标识符、日期和公式来源。公式文本与缓存结果分别使用：缓存是文件此前保存的结果，可能为空或过期。当前 Office 库不负责公式重算。

## 创建或修改

通过 `python.execute` 运行 Python，`cwd` 使用已有设备目录。输入格式为 `inputs: [{"name":"workbook","source":{...}}]`。冻结文件通过 `sked_runtime.inputs` 提供，结果写到 `output_dir`。

```python
from pathlib import Path
from openpyxl import Workbook, load_workbook
from openpyxl.styles import Font
from sked_runtime import output_dir, publish

workbook = Workbook()
sheet = workbook.active
sheet.title = "计划"
for row in [("科目", "小时"), ("数学", 6), ("英语", 4), ("合计", "=SUM(B2:B3)")]:
    sheet.append(row)
for cell in sheet[1]:
    cell.font = Font(bold=True)
sheet.column_dimensions["A"].width = 18
sheet.column_dimensions["B"].width = 12
result = Path(output_dir) / "计划.xlsx"
workbook.save(result)
check = load_workbook(result, data_only=False)
print(check["计划"]["B4"].value)
check.close()
publish(result, media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
```

修改现有文件时，冻结输入不一定带扩展名，用文件流打开：

```python
from openpyxl import load_workbook
from sked_runtime import inputs

with open(inputs["workbook"], "rb") as source:
    workbook = load_workbook(source, data_only=False)
```

只更新需要的范围，保留其他工作表、公式和用户要求保留的格式。数字、日期、布尔值按真实类型写入；学号等标识符按文本处理，避免丢失前导零。格式化数字不改变其数据类型。创建公式时保留公式本身；需要当前数值时，可用 Python 根据明确数据计算并说明该计算，不把写入公式说成已完成 Excel 重算。

保存后重新打开，核对本次涉及的表名、范围、值、类型、公式和计算依据。XLS、XLSB、加密工作簿和宏文件需要各自的处理能力，不能通过改扩展名交给 XLSX 工具。图片、视觉排版和 PDF 导出需求按当前能力目录处理。

## 保存与交付

调用 `publish` 登记实际生成的工作簿。用户指定目标目录时，用 `files.read` 将产物读为 `native` 快照，再用 `files.new` 的 `contentSnapshotId` 保存；替换原件时使用 `files.write`，其 `expected` 取原件的 `sourceVersion`。发生冲突时读取当前版本，避免覆盖期间新增的内容。

根据执行和保存回执交付真实文件位置，并准确说明公式写入或计算结果的状态。计划模式只预览 Python 代码，固定 `office.read` 可正常读取；其他模式沿用宿主权限流程。执行结果未知时核对原回执，不直接重复运行修改。
