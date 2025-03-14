#include "local_push_connectivity_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/event_sink.h>
#include <flutter/encodable_value.h>

#include "win_toast.h"
#include "win_process.h"
#include "win_socket.h"
#include "utils.h"

namespace local_push_connectivity
{
  // static
  void LocalPushConnectivityPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "local_push_connectivity",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<LocalPushConnectivityPlugin>();

    auto eventChannel(flutter::EventChannel(
        registrar->messenger(), "local_push_connectivity/events",
        &flutter::StandardMethodCodec::GetInstance()));

    eventChannel.SetStreamHandler(std::make_unique<flutter::StreamHandlerFunctions<>>(
        [](auto arguments, auto events)
        {
          if (_newMessage != L"") {
            events->Success(flutter::EncodableValue(wide_to_utf8(_newMessage)));
            _newMessage = L"";
          }
          LocalPushConnectivityPlugin::StreamListen(std::move(events));
          return nullptr;
        },
        [](auto arguments)
        {
          LocalPushConnectivityPlugin::StreamCancel();
          return nullptr;
        }));

    LocalPushNotificationProcess::WinProcess::SinkMessage([](bool isBackground, std::wstring message)
                                                          {
      wchar_t m[3072];

      swprintf(m, 3072, L"{\"type\": %s, \"data\": %s}",
      isBackground ? L"true" : L"false",
      message.c_str()
      );
      if (_event_sink != nullptr)
      {
      _event_sink->Success(flutter::EncodableValue(wide_to_utf8(m)));
      } 
    });

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result)
        {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> LocalPushConnectivityPlugin::_event_sink = nullptr;
  std::wstring _newMessage = L"";

  void LocalPushConnectivityPlugin::StreamListen(std::unique_ptr<flutter::EventSink<>> &&events)
  {
    _event_sink = std::move(events);
  }

  void LocalPushConnectivityPlugin::StreamCancel() { _event_sink = nullptr; }

  LocalPushConnectivityPlugin::LocalPushConnectivityPlugin() {}

  LocalPushConnectivityPlugin::~LocalPushConnectivityPlugin() {}

  void LocalPushConnectivityPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    const auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (method_call.method_name().compare("getPlatformVersion") == 0)
    {
      std::ostringstream version_stream;
      version_stream << "Windows ";
      if (IsWindows10OrGreater())
      {
        version_stream << "10+";
      }
      else if (IsWindows8OrGreater())
      {
        version_stream << "8";
      }
      else if (IsWindows7OrGreater())
      {
        version_stream << "7";
      }
      result->Success(flutter::EncodableValue(version_stream.str()));
    }
    else if (method_call.method_name().compare("initial") == 0)
    {
        auto app_bundle = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("appBundle")))->second));
        auto display_name = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("displayName")))->second));
        auto icon_path = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("iconNotification")))->second));
        auto icon_content = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("iconContent")))->second));
        if (arguments->find(flutter::EncodableValue("host")) != arguments->end()) {
            auto host = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("host")))->second));
            auto port = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("port")))->second));
            LocalPushNotificationProcess::WinProcess::config(host, port);
        }
        if (arguments->find(flutter::EncodableValue("publicHasKey")) != arguments->end()) {
            auto key = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("publicHasKey")))->second));
            LocalPushNotificationProcess::WinProcess::useTCPSecure(key);
        }
        else if (arguments->find(flutter::EncodableValue("wss")) != arguments->end()) {
            const bool* wss = std::get_if<bool>(&(arguments->find(flutter::EncodableValue("wss")))->second);
            auto path = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("part")))->second));
            LocalPushNotificationProcess::WinProcess::useWebsocket(path, *wss);
        }
        else {
            LocalPushNotificationProcess::WinProcess::useTCP();
        }

        try
        {
          LocalPushNotificationProcess::WinProcess::bundleId(app_bundle, icon_content);
          auto path = get_current_path() + L"\\data\\flutter_assets\\" + icon_path;
          DesktopNotificationManagerCompat::Register(app_bundle, display_name, path);

          DesktopNotificationManagerCompat::OnActivated([this](DesktopNotificationActivatedEventArgsCompat data)
                                                        {
                    std::wstring tag = data.Argument();

                    wchar_t m[3072];

                    swprintf(m, 3072, L"{\"type\": %s, \"data\": %s}",
                        L"true",
                        tag.c_str()
                    );
                    if (_event_sink != nullptr)
                    {
                        _event_sink->Success(flutter::EncodableValue(wide_to_utf8(m)));
                    }else{
                      _newMessage = m;
                    }

                    std::map<std::wstring, std::wstring> user_input;
                    for (auto&& input : data.UserInput()) {
                        user_input[input.Key().c_str()] = input.Value().c_str();
                    }
                    OnNotificationActivated(tag, user_input); });
        }
        catch (hresult_error const &e)
        {
          std::wcout << "Error native: " << e.message().c_str();
        }
        result->Success();
    }
    else if (method_call.method_name().compare("config") == 0)
    {
        auto host = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("host")))->second));
        auto port = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("port")))->second));
        try
        {
            LocalPushNotificationProcess::WinProcess::config(host, port);
            if (arguments->find(flutter::EncodableValue("publicHasKey")) != arguments->end()) {
                auto key = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("publicHasKey")))->second));
                LocalPushNotificationProcess::WinProcess::useTCPSecure(key);
            }
            else if (arguments->find(flutter::EncodableValue("wss")) != arguments->end()) {
                auto* wss = std::get_if<bool>(&(arguments->find(flutter::EncodableValue("wss")))->second);
                auto path = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("part")))->second));
                LocalPushNotificationProcess::WinProcess::useWebsocket(path, *wss);
            }
            else {
                LocalPushNotificationProcess::WinProcess::useTCP();
            }
        }
        catch (hresult_error const& e)
        {
            std::wcout << "Error native: " << e.message().c_str();
        }
        result->Success();
    }
    else if (method_call.method_name().compare("setUser") == 0)
    {
      auto userNo = utf8_to_wide_2(std::get_if<std::string>(&(arguments->find(flutter::EncodableValue("userId")))->second));
      try
      {
        LocalPushNotificationProcess::WinProcess::setUser(userNo);
        result->Success(flutter::EncodableValue(nullptr));
        if (userNo != L"null")
        {
          try
          {
            LocalPushNotificationProcess::WinProcess::CloseProcess();
            LocalPushNotificationProcess::WinProcess::CreateBackgroundProcess();
          }
          catch (hresult_error const &e)
          {
            std::wcout << "Error native: " << e.message().c_str();
          }
        }
        return;
      }
      catch (hresult_error const &e)
      {
        std::wcout << "Error native: " << e.message().c_str();
        result->Error("1", "Error native",
                      wide_to_utf8(e.message().c_str()));
        return;
      }
    }
    else if (method_call.method_name().compare("requestPermission") == 0)
    {
      result->Success(true);
    }
    else if (method_call.method_name().compare("start") == 0)
    {
      try
      {
        LocalPushNotificationProcess::WinProcess::CloseProcess();
        LocalPushNotificationProcess::WinProcess::CreateBackgroundProcess();
      }
      catch (hresult_error const &e)
      {
        std::wcout << "Error native: " << e.message().c_str();
      }
      result->Success();
    }
    else if (method_call.method_name().compare("stop") == 0)
    {
      try
      {
        LocalPushNotificationProcess::WinProcess::CloseProcess();
      }
      catch (hresult_error const &e)
      {
        std::wcout << "Error native: " << e.message().c_str();
      }
      result->Success();
    }
    else
    {
      result->NotImplemented();
    }
  }

  void LocalPushConnectivityPlugin::OnNotificationActivated(const std::wstring &argument, const std::map<std::wstring, std::wstring> &user_input)
  {
    std::map<flutter::EncodableValue, flutter::EncodableValue> user_input_value;
    for (auto &&item : user_input)
    {
      user_input_value.insert(std::make_pair(
          flutter::EncodableValue(wide_to_utf8(item.first)),
          flutter::EncodableValue(wide_to_utf8(item.second))));
    }
    flutter::EncodableMap map = {
        {flutter::EncodableValue("argument"),
         flutter::EncodableValue(wide_to_utf8(argument))},
        {flutter::EncodableValue("user_input"),
         flutter::EncodableValue(user_input_value)},
    };
  }
} // namespace local_push_connectivity
