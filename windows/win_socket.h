#pragma once
#include <functional>
#include "string"

#include <winrt/Windows.Networking.Sockets.h>
#include <winrt/Windows.Storage.Streams.h>

struct SocketParam
{
	std::string host;
	std::string port;
	std::string userId;
	std::string bundle_id;
	std::string title;
	std::string ic_content;
	bool wss;
	bool useTCP;
	std::string	ws_path;
	std::string	publicHasKey;
};

struct AppNotifyMessage {
	std::wstring title;
	std::wstring bundle;
	std::wstring iContent;
	std::wstring message;
};

class SocketClient
{
public:
	static void m_connect(SocketParam* param, std::function<void(AppNotifyMessage)> callback);

private:
	static void receiver(winrt::Windows::Networking::Sockets::StreamSocket socket);
	static void receiverWss(winrt::Windows::Networking::Sockets::StreamWebSocket socket);

	static void connect(SocketParam* param);
	static void connect_tls(SocketParam* param);
	static void connectWss(SocketParam* param);
};