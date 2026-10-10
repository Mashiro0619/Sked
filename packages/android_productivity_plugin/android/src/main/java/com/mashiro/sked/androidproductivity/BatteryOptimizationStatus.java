package com.mashiro.sked.androidproductivity;

import android.content.Context;
import android.os.Build;
import android.os.PowerManager;
import androidx.annotation.Nullable;

/** The same fail-closed battery policy query for foreground and background engines. */
public final class BatteryOptimizationStatus {
  private BatteryOptimizationStatus() {}

  public static boolean isIgnoringOptimizations(@Nullable Context context) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      return true;
    }
    if (context == null) {
      return false;
    }
    try {
      final PowerManager powerManager = context.getSystemService(PowerManager.class);
      return powerManager != null
          && powerManager.isIgnoringBatteryOptimizations(context.getPackageName());
    } catch (SecurityException ignored) {
      // Some vendor implementations reject the query; this is not a grant.
      return false;
    }
  }
}
