#include "win_process.h"
#include "win_toast.h"
#include "utils.h"

#include <thread>

#include <windows.h>
#include <flutter/standard_method_codec.h>

#include <tlhelp32.h>

#include "win_socket.h"
#include <fstream>
#include <iostream>
#include <string>

#include <stdio.h>

std::wstring _bundleId;
std::wstring _iContent;
std::wstring _title;

std::wstring _host;
std::wstring _port;

bool _wss = false;
std::wstring _ws_path;

bool _useTCP = true;
std::wstring _publicHasKey;

std::wstring _userId;

std::function<void(bool, std::wstring)> _onSinkNotification = nullptr;

void LocalPushNotificationProcess::WinProcess::SinkMessage(std::function<void(bool, std::wstring)> onSink)
{
	_onSinkNotification = onSink;
}

void LocalPushNotificationProcess::WinProcess::HandleMessage(HWND const window,
															 UINT const message,
															 LPARAM const lparam)
{
	if (message == WM_COPYDATA)
	{
		auto cp_struct = reinterpret_cast<COPYDATASTRUCT *>(lparam);
		try
		{
			const wchar_t *data = reinterpret_cast<const wchar_t *>(cp_struct->lpData);
			std::wstring strs(data, cp_struct->cbData / sizeof(wchar_t)); // cbData is in bytes
			std::wcout << "mess: " << strs;

			if (_onSinkNotification != nullptr)
			{
				_onSinkNotification(false, strs);
			}
		}
		catch (const std::exception &)
		{
			std::wcout << "error";
		}
	}
}

DWORD WINAPI LocalPushNotificationProcess::WinProcess::ThreadFunction(LPVOID lpParam)
{
	SocketParam* param = (SocketParam*)lpParam;
	try
	{
		SocketClient::m_connect(param, [](AppNotifyMessage data)
			{
				HWND hwnd = FindWindow(nullptr, data.title.c_str());

				if (!(hwnd == nullptr)) {
					// Prepare the data to send
					COPYDATASTRUCT cds;
					cds.dwData = 1; // Custom data identifier
					cds.cbData = (DWORD)(data.message.size() + 1) * sizeof(wchar_t);
					cds.lpData = (PVOID)data.message.c_str();

					SendMessage(hwnd, WM_COPYDATA, (WPARAM)GetCurrentProcessId(), (LPARAM)&cds);
				}
				else {
					DesktopNotificationManagerCompat::sendToastProcess(data.bundle, data.iContent, data.message);
				} });
	}
	catch (const winrt::hresult_error& e)
	{
		DesktopNotificationManagerCompat::sendToastProcess(utf8_to_wide(param->bundle_id), L"", e.message().c_str());
	}
	return 0;
}

void LocalPushNotificationProcess::WinProcess::StartThreadInChildProcess()
{
	SocketParam p;
	p.host = wide_to_utf8(_host);
	p.port = wide_to_utf8(_port);
	p.userId = wide_to_utf8(_userId);
	p.bundle_id = wide_to_utf8(_bundleId);
	p.title = wide_to_utf8(_title);
	p.ic_content = wide_to_utf8(_iContent);
	p.useTCP = _useTCP;
	p.wss = _wss;
	p.ws_path = wide_to_utf8(_ws_path);
	p.publicHasKey = wide_to_utf8(_publicHasKey);

	HANDLE hThread = CreateThread(
		NULL,			// Default security attributes
		0,				// Default stack size
		ThreadFunction, // Thread function
		&p,				// Parameter to thread function
		0,				// Default creation flags
		NULL			// Receive thread identifier
	);

	if (hThread == NULL)
	{
		std::wcerr << L"Error creating thread: " << GetLastError() << std::endl;
	}

	// Wait for the thread to finish
	::WaitForSingleObject(hThread, INFINITE);

	::CloseHandle(hThread); // Close the thread handle
}

void KillProcess(int pid)
{
	HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (hSnapshot == INVALID_HANDLE_VALUE)
	{
		std::cout << "Failed to take process snapshot!" << std::endl;
		return;
	}

	PROCESSENTRY32 pe;
	pe.dwSize = sizeof(PROCESSENTRY32);

	std::cout << "List of running processes:\n";
	std::cout << "-----------------------------------\n";

	if (Process32First(hSnapshot, &pe))
	{
		do
		{
			auto peId = static_cast<int>(pe.th32ProcessID);
			if (peId == pid)
			{
				std::wcout << L"PID: " << pe.th32ProcessID << L" | Name: " << pe.szExeFile << std::endl;
				HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pe.th32ProcessID);
				if (hProcess)
				{
					TerminateProcess(hProcess, 0);
					CloseHandle(hProcess);
				}
			}
			else
			{
				continue;
			}
		} while (Process32Next(hSnapshot, &pe));
	}

	CloseHandle(hSnapshot);
}

int LocalPushNotificationProcess::WinProcess::RegisterProcess(std::wstring title, _In_ wchar_t *command_line)
{
	_title = title;
	int numArgs;
	LPWSTR *argv = CommandLineToArgvW(command_line, &numArgs);

	// Check if argv is nullptr (indicates failure to parse command line)
	if (argv == nullptr)
	{
		std::cerr << "Failed to parse command line." << std::endl;
		return 1; // Error code
	}

	std::list<std::wstring> argsList;

	for (int i = 0; i < numArgs; ++i)
	{
		argsList.push_back(argv[i]);
	}

	auto it = argsList.begin();
	std::advance(it, 0);
	auto processName = *it;

	if (processName == L"child")
	{
		auto oldPid = read_pid();
		if (oldPid != -1)
		{
			KillProcess(oldPid);
		}

		DWORD processId = GetCurrentProcessId();
		write_pid(processId);

		_host = *(std::next(it, 1));
		_port = *(std::next(it, 2));
		_userId = *(std::next(it, 3));
		_bundleId = *(std::next(it, 4));
		_title = *(std::next(it, 5));
		_iContent = *(std::next(it, 6));
		_wss = *(std::next(it, 7)) == L"true";
		_useTCP = *(std::next(it, 8)) == L"true";
		_ws_path = *(std::next(it, 9));
		_publicHasKey = *(std::next(it, 10));

		LocalFree(argv);

		printf("open process\n");
		StartThreadInChildProcess();
		return 0;
	}
	else
	{
		LocalFree(argv);
		return -1;
	}
}

void LocalPushNotificationProcess::WinProcess::CloseProcess()
{
	auto pid = read_pid();
	if (pid != -1)
	{
		KillProcess(pid);
		write_pid(-1);
	}
}

int LocalPushNotificationProcess::WinProcess::CreateBackgroundProcess()
{
	PROCESS_INFORMATION pi;
	STARTUPINFO si = {0};
	si.cb = sizeof(STARTUPINFO);

	wchar_t executablePath[MAX_PATH];

	// Get the full path of the executable to ensure it's quoted properly
	if (GetModuleFileNameW(NULL, executablePath, MAX_PATH) == 0)
	{
		std::wcerr << L"GetModuleFileName failed: " << GetLastError() << std::endl;
		return -1; // Exit on failure
	}

	wchar_t commandLine[700];

	std::wstring tcp_ = _useTCP == true ? L"true" : L"false";
	std::wstring wss_ = _wss == true ? L"true" : L"false";

	swprintf(commandLine, 700, L"\"%s\" child \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\" \"%s\"",
		executablePath,
		_host.c_str(),
		_port.c_str(),
		_userId.c_str(),
		_bundleId.c_str(),
		_title.c_str(),
		_iContent.c_str(),
		wss_.c_str(),
		tcp_.c_str(),
		_ws_path.c_str(),
		_publicHasKey.c_str()
	);

	std::wcout << "exe: " << commandLine << "\n";

	if (
		CreateProcess(
			NULL,		 // No module name (use command line)
			commandLine, // Command line
			NULL,		 // Process handle not inheritable
			NULL,		 // Thread handle not inheritable
			FALSE,		 // Set handle inheritance to FALSE
			0,			 // No creation flags
			NULL,		 // Use parent's environment block
			NULL,		 // Use parent's starting directory
			&si,		 // Pointer to STARTUPINFO structure
			&pi			 // Pointer to PROCESS_INFORMATION structure
			))
	{
		std::wcout << L"Child process created successfully!" << std::endl;
		return 0;
	}
	else
	{
		std::wcerr << L"Error creating child process: " << GetLastError() << std::endl;
		return -1;
	}
}

void LocalPushNotificationProcess::WinProcess::config(const std::wstring newHost, const std::wstring newPort)
{
	_host = newHost;
	_port = newPort;
}

void LocalPushNotificationProcess::WinProcess::bundleId(const std::wstring id, const std::wstring icon_content)
{
	_bundleId = id;
	_iContent = icon_content;
}

void LocalPushNotificationProcess::WinProcess::setUser(const std::wstring newUserNo)
{
	_userId = newUserNo;
}

void LocalPushNotificationProcess::WinProcess::useTCP() {
	_useTCP = true;
	_wss = false;
	_publicHasKey = L"-";
	_ws_path = L"-";
}

void LocalPushNotificationProcess::WinProcess::useTCPSecure(const std::wstring publicHasKey) {
	_useTCP = true;
	_wss = false;
	_publicHasKey = publicHasKey;
	_ws_path = L"-";
}

void LocalPushNotificationProcess::WinProcess::useWebsocket(const std::wstring path, const bool wss) {
	_useTCP = false;
	_wss = wss == 1;
	_ws_path = path;
	_publicHasKey = L"-";
}