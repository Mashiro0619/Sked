// Current capture groups share one executable entry. Each invocation selects
// one group because native pointer/binding state is scoped to that process.
import '../capture_scenarios/category_panels.dart' as scene0;
import '../capture_scenarios/category_manager.dart' as scene1;
import '../capture_scenarios/modal_chrome.dart' as scene2;
import '../capture_scenarios/component_gallery.dart' as scene3;
import '../capture_scenarios/course_details.dart' as scene4;
import '../capture_scenarios/date_navigation.dart' as scene5;
import '../capture_scenarios/date_range_highlights.dart' as scene6;
import '../capture_scenarios/day_agenda.dart' as scene7;
import '../capture_scenarios/desktop_resize.dart' as scene8;
import '../capture_scenarios/desktop_panels.dart' as scene9;
import '../capture_scenarios/dropdown_focus.dart' as scene10;
import '../capture_scenarios/floating_panel_anchors.dart' as scene11;
import '../capture_scenarios/floating_panels.dart' as scene12;
import '../capture_scenarios/event_pickers.dart' as scene13;
import '../capture_scenarios/editor_layouts.dart' as scene14;
import '../capture_scenarios/control_gallery.dart' as scene15;
import '../capture_scenarios/mobile_calendar_interactions.dart' as scene16;
import '../capture_scenarios/mobile_calendar_grids.dart' as scene17;
import '../capture_scenarios/mobile_home.dart' as scene18;
import '../capture_scenarios/adaptive_layout.dart' as scene19;
import '../capture_scenarios/mobile_picker_surfaces.dart' as scene20;
import '../capture_scenarios/mobile_secondary_pickers.dart' as scene21;
import '../capture_scenarios/mobile_tasks.dart' as scene22;
import '../capture_scenarios/panel_headings.dart' as scene23;
import '../capture_scenarios/period_time_sets.dart' as scene24;
import '../capture_scenarios/period_times_editor.dart' as scene25;
import '../capture_scenarios/reminder_hover.dart' as scene26;
import '../capture_scenarios/reminder_summary.dart' as scene27;
import '../capture_scenarios/settings_layout.dart' as scene28;
import '../capture_scenarios/settings_transfer.dart' as scene29;
import '../capture_scenarios/student_resources.dart' as scene30;
import '../capture_scenarios/theme_tasks.dart' as scene31;
import '../capture_scenarios/teaching_weeks.dart' as scene32;
import '../capture_scenarios/compact_toolbars.dart' as scene33;
import '../capture_scenarios/workspace_chrome.dart' as scene34;
import '../capture_scenarios/workspace_editor.dart' as scene35;
import '../capture_scenarios/workspace_pages.dart' as scene36;
import '../capture_scenarios/mobile_ui_fixes.dart' as scene37;
import '../capture_scenarios/m3_expressive_controls.dart' as scene38;

const captureSceneRegistry = <String, void Function()>{
  'category-panels': scene0.registerCaptureScenarios,
  'category-manager': scene1.registerCaptureScenarios,
  'modal-chrome': scene2.registerCaptureScenarios,
  'component-gallery': scene3.registerCaptureScenarios,
  'course-details': scene4.registerCaptureScenarios,
  'date-navigation': scene5.registerCaptureScenarios,
  'date-range-highlights': scene6.registerCaptureScenarios,
  'day-agenda': scene7.registerCaptureScenarios,
  'desktop-resize': scene8.registerCaptureScenarios,
  'desktop-panels': scene9.registerCaptureScenarios,
  'dropdown-focus': scene10.registerCaptureScenarios,
  'floating-panel-anchors': scene11.registerCaptureScenarios,
  'floating-panels': scene12.registerCaptureScenarios,
  'event-pickers': scene13.registerCaptureScenarios,
  'editor-layouts': scene14.registerCaptureScenarios,
  'control-gallery': scene15.registerCaptureScenarios,
  'mobile-calendar-interactions': scene16.registerCaptureScenarios,
  'mobile-calendar-grids': scene17.registerCaptureScenarios,
  'mobile-home': scene18.registerCaptureScenarios,
  'adaptive-layout': scene19.registerCaptureScenarios,
  'mobile-picker-surfaces': scene20.registerCaptureScenarios,
  'mobile-secondary-pickers': scene21.registerCaptureScenarios,
  'mobile-tasks': scene22.registerCaptureScenarios,
  'panel-headings': scene23.registerCaptureScenarios,
  'period-time-sets': scene24.registerCaptureScenarios,
  'period-times-editor': scene25.registerCaptureScenarios,
  'reminder-hover': scene26.registerCaptureScenarios,
  'reminder-summary': scene27.registerCaptureScenarios,
  'settings-layout': scene28.registerCaptureScenarios,
  'settings-transfer': scene29.registerCaptureScenarios,
  'student-resources': scene30.registerCaptureScenarios,
  'theme-tasks': scene31.registerCaptureScenarios,
  'teaching-weeks': scene32.registerCaptureScenarios,
  'compact-toolbars': scene33.registerCaptureScenarios,
  'workspace-chrome': scene34.registerCaptureScenarios,
  'workspace-editor': scene35.registerCaptureScenarios,
  'workspace-pages': scene36.registerCaptureScenarios,
  'mobile-ui-fixes': scene37.registerCaptureScenarios,
  'm3-expressive-controls': scene38.registerCaptureScenarios,
};
