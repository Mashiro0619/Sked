<div align="center">

# Sked
### A Flutter timetable app

<a href="README.md">中文</a>
&nbsp;&nbsp;|&nbsp;&nbsp;
English
</p>

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

- Multi-timetable management: create, switch, edit, and delete timetables, and browse the semester week by week
- Course editing: edit course name, location, teacher, weeks, time, linked periods, remarks, and custom fields
- Period-time sets: reuse, edit, import, and export them across multiple timetables
- Course reminders and display: highlight the current or next course, preserve timetable gaps, show past-ended or future courses, and toggle timetable grid lines
- Theme settings: light / dark / follow system, with both single-color themes and colorful UI modes
- School webpage / HTML import: open the school site in-app and import the current page, or paste HTML manually
- Import preview and merge behavior: review parsed results before import, choose the period-time set, and decide whether to import as a new timetable or replace the current one
- Data import/export: import, export, and share timetable JSON files or plain-text timetable content
- School site management: add, edit, delete, and import or export school-site JSON entries

Everyone is welcome to submit PRs to expand `assets/school_sites.json` with more school site entries.

## Project structure

```text
lib/
├─ config/       # App configuration
├─ data/         # Platform-specific storage implementations
├─ l10n/         # Localization resources, language metadata, and generated code
├─ models/       # Timetable, course, school-site, and import response models
├─ providers/    # App state management
├─ screens/      # Screens such as home, settings, import, and school-site management
├─ services/     # Import/export, parsing, sharing, and update services
└─ widgets/      # Timetable grid, course editor, course details, and import result widgets

assets/
├─ default_period_times.json
└─ school_sites.json

web/
├─ index.html
├─ manifest.json
└─ privacy.html
```

## Privacy policy

Timetables, timetable settings, period-time sets, and school-site configuration are stored locally on your device or in the browser, and are not automatically uploaded to the developer's server.
Only when you actively use features such as import, export, sharing, external links, update checks, or webpage parsing will the app read related content or hand the corresponding operation off to the system or your configured parsing endpoint.

A privacy policy consent dialog is shown on first launch. The full privacy policy is available at [https://mashiro.tech/Sked/privacy.html](https://mashiro.tech/Sked/privacy.html).

## School webpage / HTML parsing

School webpage import and pasted HTML parsing only use the OpenAI-compatible endpoint, API key, and model that the user enters in `Timetable parser settings`.

Custom endpoints may use either `https://` or `http://` Base URLs. If you use `http://`, make sure you trust the current network and endpoint service because submitted content and API keys may not be protected by transport encryption.

### Parser configuration

- `Base URL`: OpenAI-compatible API base URL, such as `https://api.example.com/v1` or a local-network `http://192.168.1.10:8000/v1`
- `API key`: Bearer token sent to that endpoint; the app stores it with platform secure storage where available
- `Model`: chat completion model name, entered manually or fetched from the custom endpoint with `Fetch model list`
- `Custom prompt`: optional; when empty, the built-in timetable extraction prompt is used

### Request behavior

- Fetching the model list requests `/models` under the configured `Base URL`
- Parsing a timetable requests `/chat/completions` under the configured `Base URL`
- Requests include page content, optional page title, page URL, current app language, and parser prompt content
- How the custom endpoint and any upstream services store, forward, or process data depends on the service provider you choose

The app still supports `--dart-define=SKED_UPDATE_VERSION_URL=...` for overriding the update feed URL. This setting only affects update checks and is not used for timetable parsing.

## Open-source license and third-party notices

- The source code is licensed under the [GNU Affero General Public License v3.0](LICENSE)
- Bundled launcher icon and related platform icon assets include third-party licensed material; see [NOTICE](NOTICE)
- Flutter package and third-party library licenses can be viewed in the app under `Settings → Open-source licenses`
