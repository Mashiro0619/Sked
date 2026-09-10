# Sked adaptive workbench design

## Authority
Material 3 Expressive, semantic ColorScheme roles and exact saved user colors remain authoritative. Reference screenshots inform hierarchy and continuity, not imitation. No new UI, routing or state framework.

## Composition
Student timetables lead with the complete time canvas. General day/week views lead with the calendar; selected-day agenda is opt-in. Month uses calendar + selected-day agenda when space permits. List uses list/detail without a duplicated agenda. A single enabled workspace removes mode chrome, not settings access.

## Continuous surfaces
Navigation, toolbar, calendar and contextual tasks share aligned, continuous surfaces separated by hairlines. Avoid floating rounded shells around whole columns, decorative empty cards and excessive gaps. Keep rounded controls and event blocks; do not recolor saved user data. Desktop controls are compact; touch targets remain at least 48 dp.

## Task budgets
Window classes remain 600/840/1200 dp, not device classifications. WorkbenchLayoutPolicy owns actual pane decisions. Resources: 224 dp, compact: 56 pointer / 80 touch. Detail: 360, assistant: 400, base canvas: 600, seven-day calendar docking budget: 800. Forms use 224 navigation + 520 content, so an 800 dp portrait tablet can show settings categories and content even when its calendar stays a single task. Scale budgets with text; never shrink text to preserve a column.

Collapse resource navigation before overlaying detail, then overlay the independent assistant. Preserve intended widths and open states through automatic fallback. Only the top visible overlay receives focus. Calendar horizontal scrolling and week paging must not compete.

## Windows chrome
One integrated application/window row, not a second title bar. Native Win32 retains resize, move, maximize, system menu, close and HTMAXBUTTON snap semantics. Application controls must win hit tests over drag regions. Close awaits draft guards and pending saves. Android keeps its own safe areas, Back and IME behavior, never Windows caption buttons.

## Stable tasks and AI preview
Editors own drafts independently of their presentation. Ordinary workspace switching, settings visits and rotation do not discard drafts. Full data replacement must retire old editor sessions even if their workspace remains enabled. AssistantPaneController is independent from the detail navigator. The assistant is off by default. DeveloperUiPreferences stores its local show/hide choice outside AppData and backups; a saved choice overrides SKED_AI_LAYOUT_PREVIEW. A preview only displays read-only context and an unsent session draft, never fake AI actions.

## Settings and workflows
Six direct categories use the settings catalogue; there is no settings-center search. Language search remains local to the language list. Workflow preferences belong in their workspace. Explicit theme targets never change active mode. Period times are ordered rows; import source, parsing state and validation form one stable task. Dangerous operations are separate from ordinary data actions.

## Evidence
Windows full-window captures validate native chrome; Flutter render captures validate logical layout only. Neither certifies Android phone/tablet hardware. Inspect desktop and tablet-oriented layouts together, fix a consolidated batch, then confirm.

## Desktop/tablet revision (2026-09-09)
WorkbenchChromeMetrics owns desktop density: one 48 dp application/caption row at normal text, 32–36 dp commands, 46 dp caption buttons. Growing text grows the shared row. Win32 receives the measured maximize rectangle over configureChrome; do not duplicate these dimensions in C++. Android retains 48 dp touch targets.

Desktop commands are independent of mobile toolbar ordering/hidden preferences. Resource headers own add, manage, import and export. Calendar rows use colored markers and a light visibility state, not checkbox tiles. Settings live at the navigation foot; only missing navigation produces a fallback. Never duplicate workspace switching inside management/preferences menus.

Timed events first receive overlap columns; only actual day width and text size determine overflow. A small count affordance never takes a peer event column. All-day content starts with two lanes (28 dp desktop, 48 dp touch), with bounded scrolling on expansion. Preserve real event durations and all configured date/time space. Reminder status lives behind the compact toolbar action.

Appearance uses aligned labels/dropdowns with local preview, not three stretched segmented controls. Course reminders are system reminders with inherit/off/custom overrides and explicit default/permission conditions. Existing general in-app reminder behavior is separate.
