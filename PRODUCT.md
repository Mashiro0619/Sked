# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Sked primarily serves students who need to understand and maintain recurring class timetables, and people who want a local general schedule for events, reminders, calendars, and repeat rules. They use it throughout the day on phones, tablets, desktop windows, and split screens. They need a complete timetable or calendar with contextual editing on larger windows, and a focused task on narrow windows.

## Product Purpose

Sked is a local-first timetable and schedule manager. It keeps student timetable concepts such as semesters, weeks, periods, period-time sets, and courses alongside a separate general-schedule workspace for events, calendars, reminders, and recurring arrangements. Success means users can move between those two jobs without losing context, while retaining direct control over their data and theme choices.

## Positioning

Sked combines a purpose-built student timetable model and a general calendar model in one application, while giving enabled workspaces equal importance. People can use either workspace alone without seeing the other workspace's everyday controls. It also lets users import timetable data through files, school-site workflows, or a user-configured OpenAI-compatible parsing endpoint instead of depending on a bundled parsing service.

## Operating Context

- Android and Windows have release builds. Android phones and tablets and resizable Windows desktops are primary UI targets; macOS/Linux retain source compatibility and Web remains non-delivered.
- Users commonly check the active week or day, switch timetables or calendars, add and edit courses or events, manage period-time sets, and import or back up data.
- Native data lives in the operating system's application-support storage; Web uses browser local storage. User-initiated exports go to a chosen location, and API keys remain outside ordinary application backups.
- Most workflows should remain useful offline. Network access is limited to explicit import, update, external-link, and user-configured parsing actions.

## Capabilities and Constraints

- Preserve the existing student-timetable and general-schedule data models, Provider persistence interfaces, backup and recovery protocol, import and export formats, privacy boundaries, and network behavior during the visual redesign.
- Preserve exact user-selected theme colors, course colors, calendar colors, light/dark/system modes, and the current single-color or colorful theme behavior.
- Treat enabled student and general-schedule workspaces as equal primary destinations. Availability is distinct from the active mode and from navigation visibility. Disabling retains data and preferences, stops domain-specific runtime work, and leaves re-enabling in Feature management.
- New users start in the light theme; existing users retain their saved theme mode.
- Recovery gates, save-failure feedback, first-launch privacy consent, and fail-closed data protections remain higher priority than visual transitions.
- The interface is localized across the currently registered ARB locale set and must continue to work with long LTR translations.

## Brand Commitments

- Product name: Sked.
- Visual direction: Material 3 Expressive, implemented with Flutter's official Material components plus a small Sked-specific shape and motion layer where Flutter does not expose the corresponding Compose APIs.
- Keep the user's precise color selections. Expression comes primarily from shape, hierarchy, responsive composition, and purposeful motion rather than recoloring or decorative gradients.
- When both workspaces are enabled they have equal visual weight. A single-workspace setup removes mode navigation altogether rather than presenting a one-item selector.
- The product voice is direct and functional. Labels describe the action or data users control rather than implementation details.

## Evidence on Hand

- The repository contains the complete Flutter application, localization files, data and recovery tests, and representative screenshots under `docs/screenshots/`.
- `README.md` documents the current feature set, local-first data handling, Google Play distribution, import behavior, and privacy boundaries.
- Existing app icon assets are under `assets/`; their third-party attribution is recorded in `NOTICE`.
- No user research, usage analytics, performance claims, testimonials, or commercial claims are present and none should be fabricated for the interface.

## Product Principles

1. Show the user's immediate schedule state before offering configuration.
2. Give enabled workspaces direct access without forcing unused features into daily tasks.
3. Keep local data ownership, recoverability, and explicit network boundaries visible in behavior rather than promotional copy.
4. Use expressive shape and motion to clarify state changes, not to distract from dense timetable or calendar information.
5. Adapt structure to window size, text scale, input method, and platform conventions without changing the underlying task.

## Accessibility & Inclusion

- Honor Android's system animation setting and Flutter accessibility features; reduced-motion users receive an immediate or non-spatial transition.
- Keep Android primary interactive targets at least 48×48 dp. Windows uses compact 32–36 dp commands and 36 dp resource rows, with growing text budgets. Both retain visible keyboard focus and valid screen-reader labels, values, selected states, and live regions.
- Support compact phones, large screens, keyboard and pointer input, and up to 2.0× text scaling without clipping or unreachable content.
