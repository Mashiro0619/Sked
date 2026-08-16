#ifndef SKED_FLUTTER_INAPPWEBVIEW_LINUX_COMPAT_H_
#define SKED_FLUTTER_INAPPWEBVIEW_LINUX_COMPAT_H_

#include <wpe/webkit.h>

// WPE WebKit added webkit_web_view_get_theme_color in 2.50. The plugin's
// published Linux package calls it unconditionally, so older headers need the
// same no-theme-color behavior as the upstream version-gated implementation.
#if !WEBKIT_CHECK_VERSION(2, 50, 0)
static inline gboolean sked_webkit_web_view_get_theme_color(
    WebKitWebView* webview,
    WebKitColor* color) {
  (void)webview;
  (void)color;
  return FALSE;
}

#define webkit_web_view_get_theme_color sked_webkit_web_view_get_theme_color
#endif

#endif  // SKED_FLUTTER_INAPPWEBVIEW_LINUX_COMPAT_H_
