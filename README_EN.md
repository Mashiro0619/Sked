<div align="center">

# Sked
### A local-first timetable and schedule manager

<a href="README.md">中文</a>
&nbsp;&nbsp;|&nbsp;&nbsp;
English

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

Sked is a local-first app for student timetables and everyday schedules. It manages courses, semester weeks, period-time sets, school sites, general calendar events, reminders, import/export flows, and full app backups. By default, data stays on your device or in browser storage. Sked does not require a Sked account and does not automatically upload your timetable or schedule data to a developer-controlled server.

## Screenshots

<div align="center">
<img src="docs/screenshots/s1_en.jpg" width="20%" />
<img src="docs/screenshots/s2_en.jpg" width="20%" />
<img src="docs/screenshots/s3_en.jpg" width="20%" />
<img src="docs/screenshots/s4_en.jpg" width="20%" />
<img src="docs/screenshots/s5_en.jpg" width="20%" />
<img src="docs/screenshots/s6_en.jpg" width="20%" />
<img src="docs/screenshots/s7_en.jpg" width="20%" />
</div>

## Features

- **Student timetables**: create, switch, edit, and delete multiple timetables, browse by week, and highlight the current or next course.
- **Course editing**: maintain course name, location, teacher, weeks, periods, linked times, notes, and custom fields.
- **Period-time sets**: reuse, edit, import, and export period templates across multiple timetables.
- **General schedules**: manage events, calendars, reminders, recurrence rules, month/day/week views, and list view in a separate schedule mode.
- **Import and export**: handle timetable JSON files, timetable JSON text import / export, general schedule JSON / ICS, school-site JSON, period templates, sharing, and full app backup / restore.
- **Text / HTML parsing import**: open school sites in-app, or paste plain timetable text, page text, or HTML source, then parse timetable data through your own OpenAI-compatible endpoint.
- **Import preview**: review parsed results before saving, choose the period-time set, and decide whether to import as a new timetable or replace the current one.
- **Appearance**: supports light mode, dark mode, system mode, theme colors, colorful UI settings, and an ongoing Material 3 Expressive migration.
- **Privacy first**: no built-in developer-controlled parser backend, no custom parser API keys in full backups, and no default cloud backup or advertising-identifier tracking.

## Data And Privacy

Sked stores student timetables, general schedules, app settings, period-time sets, and school-site configuration locally on your device or in browser storage by default. Full app backups export this local data, but they do not include custom parser API keys.

The app reads files, writes files, invokes system sharing, opens external links, checks updates, fetches model lists, imports school webpages, or parses timetable text / HTML content only when you explicitly start the corresponding action.

A privacy policy consent screen is shown on first launch. The full policy is available at [https://mashiro.tech/Sked/privacy.html](https://mashiro.tech/Sked/privacy.html).

## Custom Parser Endpoint

Sked does not include a built-in timetable parser endpoint. School webpage import and text / HTML parsing import only use the OpenAI-compatible endpoint configured by the user in the app.

Parser settings include:

- `Base URL`: OpenAI-compatible API base URL, such as `https://api.example.com/v1` or a trusted local-network endpoint like `http://192.168.1.10:8000/v1`
- `API key`: Bearer token sent to that endpoint; the app stores it with platform secure storage where available
- `Model`: chat completion model name, entered manually or fetched from the custom endpoint
- `Custom prompt`: optional; when empty, the built-in timetable extraction prompt is used

Request behavior:

- Fetching models requests `/models` under the configured `Base URL`
- Parsing a timetable requests `/chat/completions` under the configured `Base URL`
- Requests include the submitted plain timetable text, page text or HTML content, optional page title, page URL, current app language, and parser prompt content
- If you use an `http://` Base URL, only use it on trusted devices, trusted networks, and trusted endpoint services, because content and API keys may not be protected by transport encryption

## Contributing

Issues and pull requests are welcome. Contributions to `assets/school_sites.json` are also welcome. Please preserve the existing privacy boundaries, data compatibility, and import/export behavior where possible.

## License And Notices

- Source code is licensed under the [GNU Affero General Public License v3.0](LICENSE).
- Bundled launcher icon and platform icon assets include third-party licensed material; see [NOTICE](NOTICE).
- Flutter package and third-party library licenses can be viewed in the app under `Settings -> Open-source licenses`.
