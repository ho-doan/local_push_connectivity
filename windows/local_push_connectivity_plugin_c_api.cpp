#include "include/local_push_connectivity/local_push_connectivity_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "local_push_connectivity_plugin.h"

#include "win_process.h"

void LocalPushConnectivityPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  local_push_connectivity::LocalPushConnectivityPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

int LocalPushConnectivityPluginCApiRegisterProcess(std::wstring title, _In_ wchar_t *command_line)
{
    return LocalPushNotificationProcess::WinProcess::RegisterProcess(title, command_line);
}

void LocalPushConnectivityPluginCApiHandleMessage(HWND const window, UINT const message, LPARAM const lparam)
{
    return LocalPushNotificationProcess::WinProcess::HandleMessage(window, message, lparam);
}
