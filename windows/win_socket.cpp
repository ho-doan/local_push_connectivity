#include "win_socket.h"
#include "utils.h"
#include "windows.h"
#include <iostream>
#include "local_push_connectivity_plugin.h"

#include <winrt/Windows.Networking.Sockets.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Networking.h>
#include <winrt/windows.foundation.h>
#include <memory>
#include <sstream>

using namespace winrt;
using namespace Windows::Networking::Sockets;
using namespace Windows::Networking;
using namespace Windows::Storage::Streams;
using namespace Windows::Foundation;

std::function<void(AppNotifyMessage)> _onSendNotification = nullptr;
std::wstring _app_bundle;
std::wstring _app_title;
std::wstring _app_ic_content;
std::atomic<bool> running(false);

void SocketClient::m_connect(SocketParam* param, std::function<void(AppNotifyMessage)> callback)
{
	_app_bundle = utf8_to_wide(param->bundle_id);
	_app_title = utf8_to_wide(param->title);
	_app_ic_content = utf8_to_wide(param->ic_content);
	_onSendNotification = callback;
	
	if (param->useTCP) {
		if (param->publicHasKey != "-") {
			return SocketClient::connect_tls(param);
		}
		return SocketClient::connect(param);
	}
	else {
		return SocketClient::connectWss(param);
	}
}

void SocketClient::connect(SocketParam *param)
{
	try
	{
		HostName serverHostName(utf8_to_wide(param->host));
		StreamSocket _socket;

		// Connect to the server
		_socket.ConnectAsync(serverHostName, utf8_to_wide(param->port)).get(); // Use .get() if in a non-async context
		std::wcout << "connected......\n"
				   << std::endl;

		running = true;

		// Get the output stream to send data
		DataWriter writer(_socket.OutputStream());

		std::map<std::wstring, std::wstring> data;

		data[L"MessageType"] = L"Register";
		data[L"SendId"] = utf8_to_wide(param->userId);

        auto deviceId = get_sys_device_id();

		data[L"DeviceId"] = deviceId;

		std::wstring message = ConvertMapToJSONString(data);
		writer.WriteString(message);
		writer.StoreAsync().get(); // Send the data

		receiver(_socket);
		writer.DetachStream();
		return;
	}
	catch (const winrt::hresult_error &e)
	{
		std::wcout << L"SocError: " << e.message().c_str() << L" (HRESULT: " << std::hex << e.code() << std::dec << L")" << std::endl;
		MessageBoxA(nullptr, "SocError", wide_to_utf8(e.message().c_str()).c_str(), MB_OK);
	}
}

void SocketClient::connect_tls(SocketParam* param)
{
	try
	{
		HostName serverHostName(utf8_to_wide(param->host));
		StreamSocket _socket;

		// Connect to the server
		_socket.ConnectAsync(serverHostName, utf8_to_wide(param->port), SocketProtectionLevel::Tls12).get();
		std::wcout << "connected......\n"
			<< std::endl;

		running = true;

		// Get the output stream to send data
		DataWriter writer(_socket.OutputStream());

		std::map<std::wstring, std::wstring> data;

		data[L"MessageType"] = L"Register";
		data[L"SendId"] = utf8_to_wide(param->userId);

		auto deviceId = get_sys_device_id();

		data[L"DeviceId"] = deviceId;

		std::wstring message = ConvertMapToJSONString(data);
		writer.WriteString(message);
		writer.StoreAsync().get(); // Send the data

		receiver(_socket);
		writer.DetachStream();
		return;
	}
	catch (const winrt::hresult_error& e)
	{
		std::wcout << L"SocError: " << e.message().c_str() << L" (HRESULT: " << std::hex << e.code() << std::dec << L")" << std::endl;
		MessageBoxA(nullptr, wide_to_utf8(e.message().c_str()).c_str(), "SocError", MB_OK);
	}
}

void SocketClient::connectWss(SocketParam* param)
{
	try
	{
		wchar_t uri[256];

		 auto* m = param->wss ? L"wss" : L"ws";

		swprintf(uri, 256, L"%ls://%ls:%ls%ls",
			m,
			utf8_to_wide(param->host).c_str(),
			utf8_to_wide(param->port).c_str(),
			utf8_to_wide(param->ws_path).c_str()
		);

		std::wstring uk(uri);

		Uri serverUri(uri);
		StreamWebSocket _socket;

		// Connect to the server
		_socket.ConnectAsync(serverUri).get(); // Use .get() if in a non-async context
		std::wcout << "connected......\n"
			<< std::endl;

		running = true;

		// Get the output stream to send data
		DataWriter writer(_socket.OutputStream());

		std::map<std::wstring, std::wstring> data;

		data[L"MessageType"] = L"Register";
		data[L"SendId"] = utf8_to_wide(param->userId);
        
		auto deviceId = get_sys_device_id();

		data[L"DeviceId"] = deviceId;

		std::wstring message = ConvertMapToJSONString(data);
		writer.WriteString(message);
		writer.StoreAsync().get(); // Send the data
		writer.FlushAsync().get();

		receiverWss(_socket);
		writer.DetachStream();
		return;
	}
	catch (const winrt::hresult_error& e)
	{
		std::wcout << L"SocError: " << e.message().c_str() << L" (HRESULT: " << std::hex << e.code() << std::dec << L")" << std::endl;
		MessageBoxA(nullptr, "SocError", wide_to_utf8(e.message().c_str()).c_str(), MB_OK);
	}
}

void SocketClient::receiver(StreamSocket socket)
{
	// Get the input stream to read data
	DataReader reader(socket.InputStream());
	reader.InputStreamOptions(InputStreamOptions::Partial);

	while (running)
	{
		uint32_t bytesRead = reader.LoadAsync(3072).get(); // Load up to 3072 bytes

		// check connection status(== 0 => disconnected)
		if (reader.UnconsumedBufferLength() == 0)
		{
			_onSendNotification = nullptr;
			reader.DetachStream();
			return;
		}

		if (bytesRead > 0)
		{
			auto response = reader.ReadString(bytesRead); // Read the response

			const auto data = utf8_to_wide(winrt::to_string(response));

			if (_onSendNotification != nullptr)
			{
				AppNotifyMessage notify;
				notify.title = _app_title;
				notify.bundle = _app_bundle;
				notify.iContent = _app_ic_content;
				notify.message = data;
				_onSendNotification(notify);
			}
		}
	}

	reader.DetachStream();
	_onSendNotification = nullptr;
}

void SocketClient::receiverWss(StreamWebSocket socket)
{
	// Get the input stream to read data
	DataReader reader(socket.InputStream());
	reader.InputStreamOptions(InputStreamOptions::Partial);

	while (running)
	{
		uint32_t bytesRead = reader.LoadAsync(3072).get(); // Load up to 3072 bytes

		// check connection status(== 0 => disconnected)
		if (reader.UnconsumedBufferLength() == 0)
		{
			_onSendNotification = nullptr;
			reader.DetachStream();
			return;
		}

		hstring responseMessage = reader.ReadString(reader.UnconsumedBufferLength());
		if (bytesRead > 0)
		{
			std::wcout << L"Message received: " << utf8_to_wide(winrt::to_string(responseMessage)) << std::endl;
			if (_onSendNotification != nullptr)
			{
				AppNotifyMessage notify;
				notify.title = _app_title;
				notify.bundle = _app_bundle;
				notify.iContent = _app_ic_content;
				notify.message = utf8_to_wide(winrt::to_string(responseMessage));
				_onSendNotification(notify);
			}
		}
	}

	reader.DetachStream();
	_onSendNotification = nullptr;
}