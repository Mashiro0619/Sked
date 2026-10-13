# flutter_inappwebview_windows 0.7.0-beta.3 passes DEPENDS to the TARGET form
# of add_custom_command(), where it has always been ignored. Keep that legacy
# behavior only in this plugin's directory until upstream fixes the command.
# This project() hook runs before the plugin's cmake_policy(VERSION) call, so
# the default survives that policy reset without disabling other warnings.
if(POLICY CMP0175)
  set(CMAKE_POLICY_DEFAULT_CMP0175 OLD)
endif()
