<div align="center">

# Sked

A timetable and schedule app

[简体中文](README.md) · English

[![GitHub release](https://img.shields.io/github/v/release/Mashiro0619/Sked?color=black&label=Stable&logo=github)](https://github.com/Mashiro0619/Sked/releases/latest/)
[![GitHub downloads](https://img.shields.io/github/downloads/Mashiro0619/Sked/total?label=Downloads&logo=github)](https://github.com/Mashiro0619/Sked/releases/)
[![GitHub stars](https://img.shields.io/github/stars/Mashiro0619/Sked?color=informational&label=Stars)](https://github.com/Mashiro0619/Sked/stargazers)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A53.47.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-AGPL--3.0-A42E2B?logo=gnu)](LICENSE)
[![GitHub Releases](https://img.shields.io/badge/GitHub_Releases-download-181717?logo=github&logoColor=white)](https://github.com/Mashiro0619/Sked/releases)
</div>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.mashiro.sked">
    <img src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png" alt="Get it on Google Play" height="100">
  </a>
</p>

Sked is a Flutter app for student timetables and everyday schedules. Courses are organized by semester, week, and period, while ordinary events are available in day, week, month, and list views. You can switch between the two modes at any time.

## Screenshots

### Android Phone

<p align="center">
  <a href="docs/screenshots/en/student-week.jpg"><img src="docs/screenshots/en/student-week.jpg" width="200" alt="Student timetable week view on an Android phone" title="Student timetable · Week"></a>
  <a href="docs/screenshots/en/course-details.jpg"><img src="docs/screenshots/en/course-details.jpg" width="200" alt="Course details on an Android phone" title="Course details"></a>
  <a href="docs/screenshots/en/course-editor.jpg"><img src="docs/screenshots/en/course-editor.jpg" width="200" alt="Course editor on an Android phone" title="Course editor"></a>
  <a href="docs/screenshots/en/general-week.jpg"><img src="docs/screenshots/en/general-week.jpg" width="200" alt="General schedule week view on an Android phone" title="General schedule · Week"></a>
  <a href="docs/screenshots/en/general-month.jpg"><img src="docs/screenshots/en/general-month.jpg" width="200" alt="General schedule month view on an Android phone" title="General schedule · Month"></a>
  <a href="docs/screenshots/en/general-list.jpg"><img src="docs/screenshots/en/general-list.jpg" width="200" alt="General schedule list view on an Android phone" title="General schedule · List"></a>
  <a href="docs/screenshots/en/event-details.jpg"><img src="docs/screenshots/en/event-details.jpg" width="200" alt="Event details on an Android phone" title="Event details"></a>
  <a href="docs/screenshots/en/event-editor.jpg"><img src="docs/screenshots/en/event-editor.jpg" width="200" alt="Event editor on an Android phone" title="Event editor"></a>
</p>

### Android Tablet / Windows Desktop

<p align="center">
  <a href="docs/screenshots/en/student-week-tablet.jpg"><img src="docs/screenshots/en/student-week-tablet.jpg" width="400" alt="Student timetable week view on an Android tablet" title="Student timetable · Week"></a>
  <a href="docs/screenshots/en/settings-tablet.jpg"><img src="docs/screenshots/en/settings-tablet.jpg" width="400" alt="Settings on an Android tablet" title="Settings"></a>
</p>

## Features

### Student Timetable

- Create, edit, and switch between multiple timetables, with day and week views.
- Arrange course weeks from a semester start date and total week count, with quick date and week navigation.
- Record course names, teachers, locations, periods, notes, and custom fields.
- Save multiple period-time sets for use across different timetables.
- Customize course colors, outlines, visible details, and timetable layout.
- Import timetables from JSON, plain text, HTML, or school webpages, with a preview before saving.

### General Schedule

- Create multiple calendars and browse events in day, week, month, or list views.
- Add all-day or timed events with colors, notes, and calendar assignment.
- Repeat events daily, weekly, monthly, or at a custom interval, with count and end-date limits.
- Add multiple in-app reminders to an event.
- Import and export schedules as JSON or ICS.

### Backup, Appearance, and Controls

- Back up and restore timetables, schedules, period-time sets, and app settings.
- Light, dark, system, and custom-color themes.
- Configurable course styles, date formats, toolbar sizing, and common interactions.
- Optional workspace navigation and floating add buttons on the home screen.
- Layouts that adapt to phone and desktop window sizes, with a multilingual interface.

## Getting Started

Choose Student Timetable or General Schedule on first launch. You can switch modes later from Settings and optionally hide the workspace navigation on the home screen.

For a student timetable, create a timetable and period-time set before adding courses, or import an existing timetable from a file, text, HTML, or a school webpage. For general scheduling, create a calendar and then add events or import a JSON or ICS file.

## Downloads and Platform Support

Android is Sked's primary release platform. Install it from [Google Play](https://play.google.com/store/apps/details?id=com.mashiro.sked), or download the APK from this repository's [GitHub Releases](https://github.com/Mashiro0619/Sked/releases). Windows packages are also published through GitHub Releases.

macOS and Linux are currently kept source-build compatible but do not have prebuilt packages. The project does not provide a hosted Web app or publish Web build artifacts; the Web project remains in the repository only for source compatibility.

## Official Distribution

> [!IMPORTANT]
> Official Sked releases are published only through Google Play and this repository's GitHub Releases. Packages and derivative builds offered through other app stores, download sites, mirrors, or distribution channels are not official releases and have not been verified by the maintainer.

Without explicit written authorization, a third party must not claim, label, or promote its channel or build as an "official Sked release," "official mirror," or "official partner," or use the project name, icon, or maintainer identity in a way that falsely implies official authorization, partnership, or endorsement.

Sked is currently licensed under AGPL-3.0. Anyone may redistribute the source code or independently built versions provided that the license is followed. Distributors must preserve the license and copyright notices, provide the Corresponding Source as required by AGPL-3.0, and prominently state the changes and relevant dates for modified versions.

## Custom Timetable Parsing

When importing a school webpage, text, or HTML timetable, Sked can use an OpenAI-compatible API to structure the timetable. The project does not provide a public parsing service, so the following settings must be configured in the app:

- `Base URL`: the API address, for example `https://api.example.com/v1`.
- `API key`: the Bearer token used by the API.
- `Model`: enter a model name or select one returned by the API.
- `Custom prompt`: optional; leave it empty to use the built-in timetable extraction prompt.

Sked uses `/models` for model discovery and `/chat/completions` for timetable parsing. HTTPS is recommended except for trusted local development endpoints.

## Contributing

Issues and pull requests are welcome. Before submitting code, run the formatting check, static analysis, and tests, and add coverage for new behavior.

School-site definitions are stored in [`assets/school_sites.json`](assets/school_sites.json); contributions for unlisted schools are welcome as well.

## License and Links

Sked is released under the [GNU Affero General Public License v3.0](LICENSE). See [NOTICE](NOTICE) for third-party licensing information about icons and other assets. Package licenses are available in the app under **Settings → Open-source licenses**.

- [Releases](https://github.com/Mashiro0619/Sked/releases)
- [Issue tracker](https://github.com/Mashiro0619/Sked/issues)
- [Privacy Policy](https://sked.mashiro.tech/privacy.html)
