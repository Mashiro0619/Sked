<div align="center">

# Sked
### 课表与日程管理工具

<a href="README_EN.md">English</a>
&nbsp;&nbsp;|&nbsp;&nbsp;
简体中文

[![GitHub release](https://img.shields.io/github/v/release/Mashiro0619/Sked?color=black&label=Stable&logo=github)](https://github.com/Mashiro0619/Sked/releases/latest/)
[![GitHub all releases](https://img.shields.io/github/downloads/Mashiro0619/Sked/total?label=Downloads&logo=github)](https://github.com/Mashiro0619/Sked/releases/)
[![GitHub Repo stars](https://img.shields.io/github/stars/Mashiro0619/Sked?color=informational&label=Stars)](https://github.com/Mashiro0619/Sked/stargazers)
[![Flutter](https://img.shields.io/badge/Flutter-App-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-AGPL%20v3-A42E2B?logo=gnu)](LICENSE)

</div>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.mashiro.sked">
    <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="100">
  </a>
  <br>
  <a href="https://github.com/Mashiro0619/Sked/releases">
    <img src="https://img.shields.io/badge/Get%20it%20on-GitHub%20Releases-blue?style=for-the-badge&logo=github" alt="Get it on GitHub Releases" height="28">
  </a>
</p>

Sked 是一个面向学生课表和日常安排的管理工具。你可以用它整理课程、周次、节次时间和学校站点，也可以切换到通用日程模式记录事件、提醒和重复安排。应用支持课表导入导出、完整备份恢复，以及通过自定义解析接口辅助导入学校网页或文本 / HTML 课表内容。

## 截图

<div align="center">
<img src="docs/screenshots/zh/b98a7be8de2586a28752aa39babfa9bf.jpg" width="20%" />
<img src="docs/screenshots/zh/48b7919c0f0033c227c1c77f631f9184.jpg" width="20%" />
<img src="docs/screenshots/zh/da4bcdee027eed0ee1e7e392f9904838.jpg" width="20%" />
<img src="docs/screenshots/zh/4017abc76a8a36c18f1a0f12ec778598.jpg" width="20%" />
<img src="docs/screenshots/zh/8f6f529390c675ec2175dfad9ea6f7de.jpg" width="20%" />
<img src="docs/screenshots/zh/c998f379d204901c42177571b745068a.jpg" width="20%" />
<img src="docs/screenshots/zh/3875d3da7b0b6544f2d4ab4de9a28af1.jpg" width="20%" />
</div>

## 主要功能

- **学生课表**：创建、切换、编辑和删除多个课表，按周查看课程安排，并显示当前课程、下一节课程和学期进度。
- **课程编辑**：维护课程名称、地点、教师、周次、节次、关联时间、备注和自定义字段。
- **节次时间集**：复用、编辑、导入和导出节次模板，并在多个课表之间共享。
- **通用日程**：使用独立日程模式管理事件、日历、提醒、重复规则、月视图、日视图、周视图和列表视图。
- **导入导出**：支持课表 JSON 文件、课表 JSON 文本导入 / 导出、通用日程 JSON / ICS、学校站点 JSON、节次模板、分享和完整应用备份 / 恢复。
- **文本 / HTML 解析导入**：在应用内打开学校站点，或粘贴普通课表文本、页面文本、HTML 源码，并通过你自己配置的 OpenAI 兼容接口解析课表。
- **导入预览**：保存前查看解析结果，选择节次时间集，并决定导入为新课表或替换当前课表。
- **主题与界面**：支持浅色、深色、跟随系统、主题色和多彩界面配置，并持续迁移到 Material 3 Expressive 风格。
- **数据控制**：原生平台将课表、日程和设置保存在操作系统管理的应用支持目录，浏览器版本使用浏览器本地存储；完整备份不包含自定义解析 API 密钥。

## 数据与隐私

在原生平台上，Sked 会将学生课表、通用日程、应用设置、节次时间集和学校站点配置保存在操作系统管理的应用支持目录中；浏览器版本使用浏览器本地存储。完整应用备份会导出这些数据，但不会包含自定义解析 API 密钥。

从旧版本升级时，原先写入用户“文档 / Documents”目录的文件会继续留在原处，但新版不会自动读取或迁移这些文件。如需保留其中的数据，请在升级前从旧版本导出完整应用备份，并在升级后恢复。

在桌面平台上，确认旧数据已备份或不再需要并关闭 Sked 后，可在用户“文档 / Documents”目录中选择性删除旧 Sked 数据文件、旁车文件、锁文件和恢复目录；新版不会代为清理这些遗留内容。Android 上不应手动查找或删除应用私有目录；如需清除旧版遗留，请使用系统设置中的“清除存储 / 清除数据”或卸载应用。这些操作会同时清除当前版本的本地数据，操作前请先完成备份。

只有在你主动执行导入、导出、分享、打开外部链接、检查更新、获取模型列表、学校网页导入或解析课表文本 / HTML 内容时，应用才会访问相关文件、调用系统功能或连接你配置的外部接口。

首次启动应用时会显示隐私政策确认。完整隐私政策可在 [https://sked.mashiro.tech/privacy.html](https://sked.mashiro.tech/privacy.html) 查看。

## 自定义解析接口

Sked 不内置课表解析接口。学校网页导入和文本 / HTML 解析导入只会使用你在应用内“课表解析设置”填写的 OpenAI 兼容接口。

解析配置包括：

- `Base URL`：OpenAI 兼容接口地址，例如 `https://api.example.com/v1` 或可信内网 `http://192.168.1.10:8000/v1`
- `API 密钥`：发送到该接口的 Bearer Token，应用会尽可能通过平台安全存储保存
- `模型名称`：聊天补全模型名称，可手动填写，也可从自定义接口获取模型列表
- `自定义提示词`：可选；留空时使用应用内置课表解析提示词

请求行为：

- 获取模型列表会请求你填写的 `Base URL` 下的 `/models`
- 解析课表会请求你填写的 `Base URL` 下的 `/chat/completions`
- 请求会携带你主动提交的普通课表文本、页面文本或 HTML 内容、可选页面标题、页面 URL、当前应用语言和解析提示词
- 如果使用 `http://` Base URL，请只在可信设备、可信网络和可信接口服务中使用，因为内容和 API 密钥可能不受传输层加密保护

## 贡献

欢迎提交 Issue 和 Pull Request。也欢迎为 `assets/school_sites.json` 补充学校站点配置。提交前请尽量保持现有隐私边界、数据兼容性和导入导出行为。

## 开源协议与第三方说明

- 源码基于 [GNU Affero General Public License v3.0](LICENSE) 开源。
- 项目内分发的启动图标及相关平台图标资源包含第三方授权内容，详见 [NOTICE](NOTICE)。
- Flutter 依赖与第三方库许可可在应用内“设置 -> 开源许可”查看。
