package com.mashiro.sked.androidproductivity;

import android.content.Context;
import android.os.Build;
import android.os.PowerManager;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Provides the one capability query that notification-action isolates need.
 *
 * <p>The foreground bridge lives in MainActivity and is not attached to the
 * short-lived engine created by flutter_local_notifications. Keeping this
 * channel separate avoids overriding that foreground handler while making the
 * actual PowerManager state available to every automatically registered engine.
 */
public final class AndroidProductivityBackgroundPlugin
    implements FlutterPlugin, MethodChannel.MethodCallHandler {
  private static final String CHANNEL =
      "com.mashiro.sked/android_productivity_background";
  private static final String METHOD_IS_IGNORING_BATTERY_OPTIMIZATIONS =
      "isIgnoringBatteryOptimizations";

  private Context applicationContext;
  private MethodChannel channel;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    applicationContext = binding.getApplicationContext();
    channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
    if (METHOD_IS_IGNORING_BATTERY_OPTIMIZATIONS.equals(call.method)) {
      result.success(isIgnoringBatteryOptimizations());
      return;
    }
    result.notImplemented();
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (channel != null) {
      channel.setMethodCallHandler(null);
      channel = null;
    }
    applicationContext = null;
  }

  private boolean isIgnoringBatteryOptimizations() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
      return true;
    }
    if (applicationContext == null) {
      return false;
    }
    final PowerManager powerManager =
        applicationContext.getSystemService(PowerManager.class);
    return powerManager != null
        && powerManager.isIgnoringBatteryOptimizations(applicationContext.getPackageName());
  }
}
