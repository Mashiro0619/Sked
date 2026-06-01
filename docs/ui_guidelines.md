# Sked UI Guidelines

Sked uses Material 3 Expressive as the base interaction language. These notes capture the project-level rules we want to keep consistent while the UI is being migrated and cleaned up.

## Material 3 Expressive

- Generate app color schemes with `DynamicSchemeVariant.expressive`; do not fall back to the default tonal spot scheme unless a screen has a specific accessibility reason.
- Keep the app expressive through color roles and component state, not through decorative gradients, floating blobs, or marketing-style layout.
- Use `primary`, `secondary`, and `tertiary` roles intentionally. Primary is for core actions, secondary is for navigation/selection surfaces, and tertiary is for supportive accents.
- Prefer rounded, confident component shapes for app-level controls, while keeping dense operational content compact and scannable.
- When adding a new reusable pattern, make it work in light and dark themes before using it broadly.

## Settings

- Use section headers to group settings by user intent, such as timetable, general schedule, appearance, and app.
- Use plain list rows for settings and navigation entries. Do not wrap settings pages in decorative cards.
- Avoid divider-heavy settings lists. Prefer section spacing, clear labels, and Material 3 surface colors.
- Use trailing chevrons for navigation entries, dropdown indicators for inline pickers, and external-link icons for links that leave the app.
- Use `SwitchListTile` for binary settings and dropdown controls for option sets. Use `SegmentedButton` only when the user is switching between equally prominent modes.

## Buttons

- Use `FilledButton` for the primary action in a dialog, sheet, or form.
- Use `OutlinedButton` for secondary actions that still deserve emphasis.
- Use `TextButton` for cancel, dismiss, and low-emphasis actions.
- Keep destructive actions explicit and visually distinct through wording and color.

## Dialogs And Sheets

- Dialogs should have a short title, focused content, and actions ordered from low to high emphasis.
- Bottom sheets should be task-focused and should not duplicate full-page settings screens.
- Long option sets should use scrollable sheet content, not oversized dialogs.

## States

- Empty states should explain what is missing and provide the next useful action when one exists.
- Loading states should keep layout stable and avoid shifting surrounding controls.
- Error states should say what failed and offer a recovery path when the app can provide one.

## Layout

- Keep dense operational screens scannable. Do not add marketing-style hero blocks inside app tools.
- Prefer shared layout tokens and small reusable widgets when a pattern appears across multiple screens.
- Text must fit its container on phone and desktop widths. Avoid viewport-scaled font sizes.
