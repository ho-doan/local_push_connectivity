#ifndef FLUTTER_PLUGIN_LOCAL_PUSH_CONNECTIVITY_PLUGIN_H_
#define FLUTTER_PLUGIN_LOCAL_PUSH_CONNECTIVITY_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/event_channel.h>

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

      void OnNotificationActivated(const std::wstring &argument, const std::map<std::wstring, std::wstring> &user_input);

private:
    static std::unique_ptr<flutter::EventSink<>> _event_sink;
    static void StreamListen(std::unique_ptr<flutter::EventSink<>> &&events);
    static void StreamCancel();
};

}  // namespace local_push_connectivity

#endif  // FLUTTER_PLUGIN_LOCAL_PUSH_CONNECTIVITY_PLUGIN_H_
