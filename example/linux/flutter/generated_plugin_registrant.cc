//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <local_push_connectivity/local_push_connectivity_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) local_push_connectivity_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "LocalPushConnectivityPlugin");
  local_push_connectivity_plugin_register_with_registrar(local_push_connectivity_registrar);
}
