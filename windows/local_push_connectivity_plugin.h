#ifndef FLUTTER_PLUGIN_LOCAL_PUSH_CONNECTIVITY_PLUGIN_H_
#define FLUTTER_PLUGIN_LOCAL_PUSH_CONNECTIVITY_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace local_push_connectivity {

class LocalPushConnectivityPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  LocalPushConnectivityPlugin();

  virtual ~LocalPushConnectivityPlugin();

  // Disallow copy and assign.
  LocalPushConnectivityPlugin(const LocalPushConnectivityPlugin&) = delete;
  LocalPushConnectivityPlugin& operator=(const LocalPushConnectivityPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace local_push_connectivity

#endif  // FLUTTER_PLUGIN_LOCAL_PUSH_CONNECTIVITY_PLUGIN_H_
