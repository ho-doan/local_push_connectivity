#include <windows.h>
#include <iostream>
#include "win_socket.h"

namespace LocalPushNotificationProcess
{
	class WinProcess
	{
	public:
		static int RegisterProcess(std::wstring title, _In_ wchar_t *command_line);
		static void HandleMessage(HWND const window, UINT const message, LPARAM const lparam);
		static void SinkMessage(std::function<void(bool, std::wstring)> onSink);
		static int CreateBackgroundProcess();
		static void CloseProcess();

		static void bundleId(const std::wstring id, const std::wstring icon_content);
		static void config(const std::wstring host, const std::wstring port);

		static void useTCP();
		static void useTCPSecure(const std::wstring publicHasKey);
		static void useWebsocket(const std::wstring path,const bool wss);

		static void setUser(const std::wstring userNo);

	private:
		static DWORD WINAPI ThreadFunction(LPVOID lpParam);
		static void StartThreadInChildProcess();
	};
}
