# Sked — Microsoft Store listing (English, United States)

适用：当前 Windows x64 Store 包，应用版本 `2.3.0-alpha.1+14`，MSIX 版本 `2.3.14.0`。这是本地提交素材草稿，不代表已经上架或通过认证。

## 填写速查

| 后台字段 | 填写内容 |
| --- | --- |
| 产品名称 | Sked |
| 说明 | 使用下方 Description，或素材包中的 description.txt |
| 此版本的新增功能 | 首次提交留空，不要粘贴“留空”或 Initial release |
| 产品功能 | 下方每一项单独添加，共 11 项 |
| 屏幕截图 | 上传 screenshots/ 中的 5 张桌面截图，按文件名前缀排序 |
| 海报 | 可选：artwork/poster-720x1080.png |
| 1:1 酷图 | 可选：artwork/square-artwork-1080x1080.png |
| 应用磁贴图标 | 可选：artwork/tile-300x300.png、tile-150x150.png、tile-71x71.png |
| 预告片、16:9 主角图像 | 本次不使用预告片，可留空 |
| Xbox 专用图像 | 当前包仅支持 Windows.Desktop，不填写 Xbox 专用项 |
| 短标题、语音标题 | Windows 上架可留空；如后台需要短标题，使用 Sked |
| 简短描述 | 使用下方 Short description |
| 关键字 | 下方 7 个关键词，每个作为一个标签添加 |
| 版权和商标信息 | 可选，暂留空；仅填写你核实过的版权权利人、年份和商标声明 |
| 其他许可条款 | 下方 Additional license terms 与当前仓库 AGPL-3.0 一致；提交前核对源码可获得性 |
| 开发者 | Mashiro0619 |

## Description

Sked brings your class timetable and everyday plans together in one local-first Windows app.

PLAN YOUR SEMESTER
Create separate timetables for different terms. Organize classes by teaching week and period, and keep course names, instructors, rooms, notes, and custom details in one place.

ORGANIZE THE REST OF YOUR WEEK
Use separate calendars for study, personal plans, and projects. Browse day, week, month, list, or custom date-range views. Add timed or all-day events, repeating schedules, and reminders.

MAKE ROOM FOR YOUR WORKFLOW
Use a desktop workspace with a resource sidebar and detail and editing panels. Adjust colors, course styles, period times, and light or dark themes to fit your routine.

KEEP CONTROL OF YOUR DATA
Your timetable and calendar data is stored locally. Import supported timetable files and preview entries before saving. Import and export calendars in JSON or ICS, and create full app backups to move or restore your setup. Core planning works offline and does not require an account. Optional online imports require an internet connection and may use third-party services.

This release is an Alpha preview. Back up important data before upgrading. Windows notifications depend on system permissions and settings.

## Short description

Plan classes and everyday events with a local-first timetable and calendar. Organize your semester, set reminders, and make your schedule your own.

字符数：147，低于后台建议的 270。

## Product features

- Semester-based class timetables with configurable teaching weeks and periods.
- Separate calendars for study, projects, and personal plans.
- Day, week, month, list, and custom 1–14-day calendar views.
- Timed and all-day events with flexible repeating schedules.
- Course and event reminders using Windows notifications.
- Course details with instructors, locations, notes, and custom fields.
- Timetable import previews and JSON/ICS calendar import and export.
- Full app backup and restore for local data and settings.
- Light, dark, and custom-color themes with adjustable course styling.
- Adaptive desktop sidebar and detail/editing panels.
- Multilingual interface, including English.

## Keywords

- timetable
- class schedule
- student planner
- calendar
- daily planner
- reminders
- offline planner

共 7 个关键词、11 个英文单词；最长关键词 15 个字符，符合每项 40 字符、总计 21 个单词的限制。

## Additional license terms

Sked is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

Source code and license: https://github.com/Mashiro0619/Sked

Third-party components and icon assets remain subject to their own license terms. See the included NOTICE file and the in-app open-source licenses page.

## Screenshot order and optional captions

| 文件 | 尺寸 | 可选英文说明 |
| --- | --- | --- |
| 01-student-timetable.png | 1600 × 1000 | Organize your semester with a clear weekly class timetable. |
| 02-week-calendar.png | 1600 × 1000 | Plan study, projects, and personal events in separate calendars. |
| 03-month-calendar-dark.png | 1600 × 1000 | See the month at a glance and review the selected day's plans in dark mode. |
| 04-course-editor.png | 1600 × 1000 | Edit course details alongside your timetable. |
| 05-appearance.png | 1600 × 1000 | Choose theme colors and adjust the look of your timetable. |

截图由当前项目的真实 Flutter 界面渲染，语言为 en-US，使用隔离的内存示例数据与 Windows 桌面样式。没有读取个人课表、保存到真实用户目录或发送系统通知。截图不等于安装、通知投递或 WACK 的验证结果。界面没有重绘成虚构产品效果图；海报和方形品牌图属于单独的宣传图片，不应替代产品截图。

## Images and upload limits

- 图片均为 PNG。桌面截图为 1600 × 1000，高于后台建议的 1366 × 768。各文件尺寸和 SHA-256 记录在素材包 manifest.json 中。
- 海报按你贴出的后台像素要求制作成 **720 × 1080**。注意：该尺寸数学上是 **2:3**，并不是页面文字所说的 9:16。以后台实际接受的像素规格为准，不能仅按比例名称擅自改成 720 × 1280。
- 1:1 品牌图为 1080 × 1080；磁贴图标为 300 × 300、150 × 150、71 × 71。都使用项目现有图标，没有 Microsoft 或商店认证徽章。
- preview-contact-sheet.jpg 仅供预览，不是商店截图上传文件。

## Before publishing

1. 当前是 Alpha 预览版本；文案已如实注明。版本后缀不会自动创建商店测试渠道，必须单独确认产品可见性和发布范围。
2. 首次提交按后台说明保持 What's new 为空。以后更新时填写实际版本变化。
3. 核心规划功能可离线使用，不需要应用账号；但学校网页、解析 API 等可选功能会联网，不应宣称“所有数据绝不离开设备”。文本/HTML 等高级课表解析可能需要用户配置第三方 API，未宣传为免费内置 AI 服务。
4. 没有宣传自动云同步、已接入的 AI 对话、支持所有学校，或“绝不错过提醒”等未经证实的能力。
5. 当前代码许可为 AGPL-3.0。确保接收此版本的用户能够获得与最终二进制对应的源码和许可证；建议公开最终打包提交及版本标签。不能仅提供不包含当前改动的旧版源码。不要擅自添加“禁止复制/修改”等与已有许可证冲突的条款。
6. 图标衍生自 Material Icons / Symbols，相关 Apache-2.0 信息见素材包 ARTWORK-NOTICE.txt；不要填写“全部图形均为独立原创”或未经确认的注册商标声明。
7. 若其他页面要求链接，可使用现有 [隐私政策](https://sked.mashiro.tech/privacy.html) 与 [问题反馈](https://github.com/Mashiro0619/Sked/issues)，提交前确认页面正常可访问。
8. 上架前仍需完成 WACK、真实安装/升级/通知测试及商店认证；本素材包不包含这些通过承诺。
