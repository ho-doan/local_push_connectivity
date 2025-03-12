#include <string>
#include <Windows.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <sstream>
#include <winrt/Windows.Storage.h>

#include <winrt/Windows.Data.Json.h>
#include <unordered_map>
#include <iostream>
#include <any>
#include <fstream>

#include <regex>

using namespace winrt;
using namespace Windows::Storage;

static inline std::wstring _get_path_app()
{
	wchar_t executablePath[MAX_PATH];

	// Get the full path of the executable to ensure it's quoted properly
	if (GetModuleFileNameW(NULL, executablePath, MAX_PATH) == 0)
	{
		std::wcerr << L"GetModuleFileName failed: " << GetLastError() << std::endl;
		return L"";
	}

	return std::wstring(executablePath);
}

static inline std::vector<std::wstring> _split(const std::wstring &str, const wchar_t delimiter)
{
	std::vector<std::wstring> tokens;
	std::wstring token;
	std::wistringstream tokenStream(str);

	while (std::getline(tokenStream, token, delimiter))
	{
		tokens.push_back(token);
	}

	return tokens;
}

static inline std::wstring get_current_path()
{
	auto path = _get_path_app();
	std::vector<std::wstring> segments = _split(path, L'\\');

	if (!segments.empty())
	{
		segments.pop_back();
	}

	std::wstring result;
	for (size_t i = 0; i < segments.size(); ++i)
	{
		result += segments[i];
		if (i < segments.size() - 1)
		{
			result += L'\\';
		}
	}

	return result;
}

static inline std::wstring _cp_to_wide(const std::string &s, UINT codepage)
{
	int in_length = (int)s.length();
	int out_length = MultiByteToWideChar(codepage, 0, s.c_str(), in_length, 0, 0);
	std::wstring result(out_length, L'\0');
	if (out_length)
		MultiByteToWideChar(codepage, 0, s.c_str(), in_length, &result[0], out_length);
	return result;
}
static inline std::wstring utf8_to_wide(const std::string &s)
{
	return _cp_to_wide(s, CP_UTF8);
}

static inline std::wstring utf8_to_wide_2(const std::string *s)
{
	return std::wstring(s->begin(), s->end());
}

static inline std::string _wide_to_cp(const std::wstring &s, UINT codepage)
{
	int in_length = (int)s.length();
	int out_length = WideCharToMultiByte(codepage, 0, s.c_str(), in_length, 0, 0, 0, 0);
	std::string result(out_length, '\0');
	if (out_length)
		WideCharToMultiByte(codepage, 0, s.c_str(), in_length, &result[0], out_length, 0, 0);
	return result;
}
static inline std::string wide_to_utf8(const std::wstring &s)
{
	return _wide_to_cp(s, CP_UTF8);
}

static inline std::wstring ConvertMapToJSONString(const std::map<std::wstring, std::wstring> &data)
{
	std::wstringstream jsonStream;
	jsonStream << L"{";

	bool firstEntry = true;
	for (const auto &pair : data)
	{
		if (!firstEntry)
		{
			jsonStream << L", ";
		}
		jsonStream << L"\"" << pair.first << L"\": \"" << pair.second << L"\"";
		firstEntry = false;
	}

	jsonStream << L"}";
	return jsonStream.str();
}

static inline std::unordered_map<std::wstring, std::any> json_to_map(const winrt::Windows::Data::Json::JsonObject &jsonObject)
{
	std::unordered_map<std::wstring, std::any> map;

	for (const auto &keyValue : jsonObject)
	{
		const auto key = utf8_to_wide(winrt::to_string(keyValue.Key()));
		const auto &value = keyValue.Value();

		// Assuming you want to convert all values to string for the map
		if (value.ValueType() == winrt::Windows::Data::Json::JsonValueType::String)
		{
			map[key] = value.GetString();
		}
		else if (value.ValueType() == winrt::Windows::Data::Json::JsonValueType::Number)
		{
			map[key] = value.GetNumber();
		}
	}

	return map;
}

static inline int read_pid()
{
	std::wstring path = get_current_path() + L"\\app_system.ini";
	wchar_t buffer[256];
	DWORD size = GetPrivateProfileString(L"process", L"pid", L"", buffer, sizeof(buffer) / sizeof(wchar_t), path.c_str());

	if (size > 0)
	{
		auto pid = std::wstring(buffer);
		return std::stoi(pid);
	}
	else
	{
		std::wcerr << L"Failed to read from INI file." << std::endl;
		return -1;
	}
}

static inline BOOL write_pid(int pid)
{
	auto pid_str = std::to_wstring(pid);
	std::wstring path = get_current_path() + L"\\app_system.ini";
	std::ifstream fileCheck(path);
	if (!fileCheck.good())
	{
		std::ofstream outFile(path);
		if (outFile)
		{
			outFile.close();
		}
	}
	return WritePrivateProfileString(L"process", L"pid", pid_str.c_str(), path.c_str());
}

static inline std::wstring get_sys_device_id() {
	HKEY hKey;
	const wchar_t* subkey = L"SOFTWARE\\Microsoft\\SQMClient"; //SOFTWARE\\Microsoft\\Cryptography
	const wchar_t* valueName = L"MachineId";//MachineGuid
	wchar_t machineGuid[64];
	DWORD size = sizeof(machineGuid);

	// Open the registry key
	if (RegOpenKeyExW(HKEY_LOCAL_MACHINE, subkey, 0, KEY_READ, &hKey) == ERROR_SUCCESS) {
		// Query the MachineGuid value from the registry
		if (RegQueryValueExW(hKey, valueName, nullptr, nullptr, (BYTE*)machineGuid, &size) == ERROR_SUCCESS) {
			RegCloseKey(hKey);
			std::string str = wide_to_utf8(machineGuid);

			str = std::regex_replace(str, std::regex("\\{|\\}"), "");
			return utf8_to_wide(str);
		}
		RegCloseKey(hKey);
	}
	return L"Error";
}