
#include "pch.h"
#include "win_toast.h"

#include <winrt/Windows.ApplicationModel.h>
#include <Windows.h>
#include <appmodel.h>
#include "NotificationActivationCallback.h"
#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Foundation.Collections.h>

#include <winrt/Windows.UI.Notifications.h>
#include <winrt/Windows.Data.Xml.Dom.h>

#include <iostream>

// #region include model
#include <winrt/Windows.Data.Json.h>
#include <string>
#include <fstream>
#include "utils.h"
// #endregion

using namespace winrt::Windows::Data::Xml::Dom;
using namespace winrt::Windows::UI::Notifications;

using namespace winrt;
using namespace Windows::ApplicationModel;
using namespace Windows::UI::Notifications;
using namespace Windows::Foundation::Collections;

// Create a JsonObject from the provided JSON string
using namespace winrt::Windows::Data::Json;

struct Win32AppInfo
{
	std::wstring Aumid;
	std::wstring DisplayName;
	std::wstring IconPath;
};

bool IsContainerized();
bool HasIdentity();
void SetRegistryKeyValue(HKEY hKey, std::wstring subKey, std::wstring valueName, std::wstring value);
void DeleteRegistryKeyValue(HKEY hKey, std::wstring subKey, std::wstring valueName);
void DeleteRegistryKey(HKEY hKey, std::wstring subKey);
void EnsureRegistered();
std::wstring CreateAndRegisterActivator();
std::wstring GenerateGuid(std::wstring name);
std::wstring get_module_path();

std::wstring _win32Aumid;
std::function<void(DesktopNotificationActivatedEventArgsCompat)> _onActivated = nullptr;

void DesktopNotificationManagerCompat::Register(std::wstring aumid, std::wstring displayName, std::wstring iconPath)
{
	// If has identity
	if (HasIdentity())
	{
		// No need to do anything additional, already registered through manifest
		return;
	}

	_win32Aumid = aumid;

	std::wstring clsidStr = CreateAndRegisterActivator();

	// Register via registry
	std::wstring subKey = LR"(SOFTWARE\Classes\AppUserModelId\)" + _win32Aumid;

	// Set the display name and icon uri
	SetRegistryKeyValue(HKEY_CURRENT_USER, subKey, L"DisplayName", displayName);

	if (!iconPath.empty())
	{
		SetRegistryKeyValue(HKEY_CURRENT_USER, subKey, L"IconUri", iconPath);
	}
	else
	{
		DeleteRegistryKeyValue(HKEY_CURRENT_USER, subKey, L"IconUri");
	}

	// Background color only appears in the settings page, format is
	// hex without leading #, like "FFDDDDDD"
	SetRegistryKeyValue(HKEY_CURRENT_USER, subKey, L"IconBackgroundColor", iconPath);

	SetRegistryKeyValue(HKEY_CURRENT_USER, subKey, L"CustomActivator", L"{" + clsidStr + L"}");
}

void DesktopNotificationManagerCompat::OnActivated(std::function<void(DesktopNotificationActivatedEventArgsCompat)> callback)
{
	EnsureRegistered();

	_onActivated = callback;
}

void EnsureRegistered()
{
	if (!HasIdentity() && _win32Aumid.empty())
	{
		throw "Must call Register first.";
	}
}

ToastNotifier DesktopNotificationManagerCompat::CreateToastNotifier()
{
	if (HasIdentity())
	{
		return ToastNotificationManager::CreateToastNotifier();
	}
	else
	{
		return ToastNotificationManager::CreateToastNotifier(_win32Aumid);
	}
}

ToastNotifier DesktopNotificationManagerCompat::CreateToastNotifierProcess(std::wstring aumid)
{
	return ToastNotificationManager::CreateToastNotifier(aumid);
}

void DesktopNotificationManagerCompat::Uninstall()
{
	if (IsContainerized())
	{
		// Packaged containerized apps automatically clean everything up already
		return;
	}

	if (!HasIdentity() && !_win32Aumid.empty())
	{
		try
		{
			// Remove all scheduled notifications (do this first before clearing current notifications)
			auto notifier = CreateToastNotifier();
			auto scheduled = notifier.GetScheduledToastNotifications();
			for (unsigned int i = 0; i < scheduled.Size(); i++)
			{
				try
				{
					notifier.RemoveFromSchedule(scheduled.GetAt(i));
				}
				catch (...)
				{
				}
			}
		}
		catch (...)
		{
		}

		try
		{
			// Clear all current notifications
			History().Clear();
		}
		catch (...)
		{
		}
	}

	try
	{
		// Remove registry key
		if (!_win32Aumid.empty())
		{
			std::wstring subKey = LR"(SOFTWARE\Classes\AppUserModelId\)" + _win32Aumid;
			DeleteRegistryKey(HKEY_CURRENT_USER, subKey);
		}
	}
	catch (...)
	{
	}
}

void DesktopNotificationManagerCompat::sendToast()
{
	std::cout << "\n\nSending a toast... ";

	// Construct the toast template
	XmlDocument doc;
	doc.LoadXml(L"<toast>\
    <visual>\
        <binding template=\"ToastGeneric\">\
            <text></text>\
            <text></text>\
            <image placement=\"appLogoOverride\" hint-crop=\"circle\"/>\
            <image/>\
        </binding>\
    </visual>\
    <actions>\
        <input\
            id=\"tbReply\"\
            type=\"text\"\
            placeHolderContent=\"Type a reply\"/>\
        <action\
            content=\"Reply\"\
            activationType=\"background\"/>\
        <action\
            content=\"Like\"\
            activationType=\"background\"/>\
        <action\
            content=\"View\"\
            activationType=\"background\"/>\
    </actions>\
</toast>");

	// Populate with text and values
	doc.DocumentElement().SetAttribute(L"launch", L"action=viewConversation&conversationId=9813");
	doc.SelectSingleNode(L"//text[1]").InnerText(L"Andrew sent you a picture");
	doc.SelectSingleNode(L"//text[2]").InnerText(L"Check this out, Happy Canyon in Utah!");
	doc.SelectSingleNode(L"//image[1]").as<XmlElement>().SetAttribute(L"src", L"https://unsplash.it/64?image=1005");
	doc.SelectSingleNode(L"//image[2]").as<XmlElement>().SetAttribute(L"src", L"https://picsum.photos/364/202?image=883");
	doc.SelectSingleNode(L"//action[1]").as<XmlElement>().SetAttribute(L"arguments", L"action=reply&conversationId=9813");
	doc.SelectSingleNode(L"//action[2]").as<XmlElement>().SetAttribute(L"arguments", L"action=like&conversationId=9813");
	doc.SelectSingleNode(L"//action[3]").as<XmlElement>().SetAttribute(L"arguments", L"action=viewImage&imageUrl=https://picsum.photos/364/202?image=883");

	// Construct the notification
	ToastNotification notif{doc};

	// And send it!
	DesktopNotificationManagerCompat::CreateToastNotifier().Show(notif);

	std::cout << "Sent!\n";
}

void DesktopNotificationManagerCompat::sendToastProcess(std::wstring aumid, std::wstring iContent, std::wstring message)
{
	std::cout << "\n\nSending a toast... ";

	// Construct the toast template
	XmlDocument doc;
	doc.LoadXml(L"<toast>\
    <visual>\
        <binding template=\"ToastGeneric\">\
			<image placement=\"appLogoOverride\" hint-crop=\"circle\"/>\
            <text></text>\
            <text></text>\
        </binding>\
    </visual>\
</toast>");

	// #region parse message
	//  Get Title and Body
	std::wstring title;
	std::wstring content;

	try
	{
		JsonObject jsonObject = JsonObject::Parse(message);

		auto notificationObject = jsonObject.GetNamedObject(L"Notification");

		if (notificationObject.HasKey(L"Title"))
		{
			title = notificationObject.GetNamedString(L"Title", L"");
		}

		if (notificationObject.HasKey(L"Body"))
		{
			content = notificationObject.GetNamedString(L"Body", L"");
		}
	}
	catch (hresult_error const &e)
	{
		content = e.message().c_str();
	}

	// #endregion

	// Populate with text and values
	doc.DocumentElement().SetAttribute(L"launch", message);
	doc.SelectSingleNode(L"//text[1]").InnerText(title);
	doc.SelectSingleNode(L"//text[2]").InnerText(content);
	auto path = get_current_path() + L"\\data\\flutter_assets\\" + iContent;
	doc.SelectSingleNode(L"//image[1]").as<XmlElement>().SetAttribute(L"src", path);

	// Construct the notification
	ToastNotification notif{doc};

	// And send it!
	DesktopNotificationManagerCompat::CreateToastNotifierProcess(aumid).Show(notif);

	std::cout << "Sent!\n";
}

std::wstring GenerateGuid(std::wstring name)
{
	if (name.length() <= 16)
	{
		wchar_t guid[36];
		swprintf_s(
			guid,
			36,
			L"%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
			name[0], name[1], name[2], name[3], name[4], name[5], name[6], name[7], name[8], name[9], name[10], name[11], name[12], name[13], name[14], name[15]);
		return guid;
	}
	else
	{
		std::size_t hash = std::hash<std::wstring>{}(name);

		// Only ever at most 20 chars long
		std::wstring hashStr = std::to_wstring(hash);

		wchar_t guid[37];
		for (int i = 0; i < 36; i++)
		{
			if (i == 8 || i == 13 || i == 18 || i == 23)
			{
				guid[i] = '-';
			}
			else
			{
				int strPos = i;
				if (i > 23)
				{
					strPos -= 4;
				}
				else if (i > 18)
				{
					strPos -= 3;
				}
				else if (i > 13)
				{
					strPos -= 2;
				}
				else if (i > 8)
				{
					strPos -= 1;
				}

				if (strPos < hashStr.length())
				{
					guid[i] = hashStr[strPos];
				}
				else
				{
					guid[i] = '0';
				}
			}
		}

		guid[36] = '\0';

		return guid;
	}
}

// https://docs.microsoft.com/en-us/windows/uwp/cpp-and-winrt-apis/author-coclasses#implement-the-coclass-and-class-factory
struct callback : implements<callback, INotificationActivationCallback>
{
	HRESULT __stdcall Activate(
		LPCWSTR appUserModelId,
		LPCWSTR invokedArgs,
		[[maybe_unused]] NOTIFICATION_USER_INPUT_DATA const *data,
		[[maybe_unused]] ULONG dataCount) noexcept
	{
		if (_onActivated != nullptr)
		{
			std::wstring argument(invokedArgs);

			StringMap userInput;

			for (unsigned int i = 0; i < dataCount; i++)
			{
				userInput.Insert(data[i].Key, data[i].Value);
			}

			DesktopNotificationActivatedEventArgsCompat args(argument, userInput);
			_onActivated(args);
		}
		return S_OK;
	}
};

struct callback_factory : implements<callback_factory, IClassFactory>
{
	HRESULT __stdcall CreateInstance(
		IUnknown *outer,
		GUID const &iid,
		void **result) noexcept
	{
		*result = nullptr;

		if (outer)
		{
			return CLASS_E_NOAGGREGATION;
		}

		return make<callback>()->QueryInterface(iid, result);
	}

	HRESULT __stdcall LockServer(BOOL) noexcept
	{
		return S_OK;
	}
};

std::wstring CreateAndRegisterActivator()
{
	// Need to initialize the thread
	// winrt::check_hresult(CoInitializeEx(NULL, COINIT_MULTITHREADED));

	DWORD registration{};
	std::wstring clsidStr = GenerateGuid(_win32Aumid);
	GUID clsid;
	winrt::check_hresult(::CLSIDFromString((L"{" + clsidStr + L"}").c_str(), &clsid));

	// Register callback
	auto result = CoRegisterClassObject(
		clsid,
		make<callback_factory>().get(),
		CLSCTX_LOCAL_SERVER,
		REGCLS_MULTIPLEUSE,
		&registration);

	winrt::check_hresult(result);

	// Create launch path+args
	// Include a flag so we know this was a toast activation and should wait for COM to process
	// We also wrap EXE path in quotes for extra security
	std::string launchArg = TOAST_ACTIVATED_LAUNCH_ARG;
	std::wstring launchArgW(launchArg.begin(), launchArg.end());
	std::wstring launchStr = L"\"" + get_module_path() + L"\" " + launchArgW;

	// Update registry with activator
	std::wstring key_path = LR"(SOFTWARE\Classes\CLSID\{)" + clsidStr + LR"(}\LocalServer32)";
	SetRegistryKeyValue(HKEY_CURRENT_USER, key_path, L"", launchStr);

	return clsidStr;
}

std::wstring get_module_path()
{
	std::wstring path(100, L'?');
	uint32_t path_size{};
	DWORD actual_size{};

	do
	{
		path_size = static_cast<uint32_t>(path.size());
		actual_size = ::GetModuleFileName(nullptr, path.data(), path_size);

		if (actual_size + 1 > path_size)
		{
			path.resize(path_size * 2, L'?');
		}
	} while (actual_size + 1 > path_size);

	path.resize(actual_size);
	return path;
}

void SetRegistryKeyValue(HKEY hKey, std::wstring subKey, std::wstring valueName, std::wstring value)
{
	winrt::check_hresult(::RegSetKeyValue(
		hKey,
		subKey.c_str(),
		valueName.empty() ? nullptr : valueName.c_str(),
		REG_SZ,
		reinterpret_cast<const BYTE *>(value.c_str()),
		static_cast<DWORD>((value.length() + 1) * sizeof(WCHAR))));
}

void DeleteRegistryKeyValue(HKEY hKey, std::wstring subKey, std::wstring valueName)
{
	winrt::check_hresult(::RegDeleteKeyValue(
		hKey,
		subKey.c_str(),
		valueName.c_str()));
}

void DeleteRegistryKey(HKEY hKey, std::wstring subKey)
{
	winrt::check_hresult(::RegDeleteKey(
		hKey,
		subKey.c_str()));
}

bool _checkedIsContainerized;
bool _isContainerized;
bool IsContainerized()
{
	if (!_checkedIsContainerized)
	{
		// If MSIX or sparse
		if (HasIdentity())
		{
			// Sparse is identified if EXE is running outside of installed package location
			winrt::hstring packageInstalledLocation = Package::Current().InstalledLocation().Path();
			wchar_t exePath[MAX_PATH];
			DWORD charWritten = GetModuleFileNameW(nullptr, exePath, ARRAYSIZE(exePath));
			if (charWritten == 0)
			{
				throw HRESULT_FROM_WIN32(GetLastError());
			}

			// If inside package location
			std::wstring stdExePath = exePath;
			if (stdExePath.find(packageInstalledLocation.c_str()) == 0)
			{
				_isContainerized = true;
			}
			else
			{
				_isContainerized = false;
			}
		}

		// Plain Win32
		else
		{
			_isContainerized = false;
		}

		_checkedIsContainerized = true;
	}

	return _isContainerized;
}

bool _checkedHasIdentity;
bool _hasIdentity;
bool HasIdentity()
{
	if (!_checkedHasIdentity)
	{
		// https://stackoverflow.com/questions/39609643/determine-if-c-application-is-running-as-a-uwp-app-in-desktop-bridge-project
		UINT32 length;
		wchar_t packageFamilyName[PACKAGE_FAMILY_NAME_MAX_LENGTH + 1];
		LONG result = GetPackageFamilyName(GetCurrentProcess(), &length, packageFamilyName);
		_hasIdentity = result == ERROR_SUCCESS;

		_checkedHasIdentity = true;
	}

	return _hasIdentity;
}

DesktopNotificationHistoryCompat DesktopNotificationManagerCompat::History()
{
	EnsureRegistered();

	DesktopNotificationHistoryCompat history(_win32Aumid);
	return history;
}

void DesktopNotificationHistoryCompat::Clear()
{
	if (_win32Aumid.empty())
	{
		_history.Clear();
	}
	else
	{
		_history.Clear(_win32Aumid);
	}
}

IVectorView<ToastNotification> DesktopNotificationHistoryCompat::GetHistory()
{
	if (_win32Aumid.empty())
	{
		return _history.GetHistory();
	}
	else
	{
		return _history.GetHistory(_win32Aumid);
	}
}

void DesktopNotificationHistoryCompat::Remove(std::wstring tag)
{
	if (_win32Aumid.empty())
	{
		_history.Remove(tag);
	}
	else
	{
		_history.Remove(tag, L"", _win32Aumid);
	}
}

void DesktopNotificationHistoryCompat::Remove(std::wstring tag, std::wstring group)
{
	if (_win32Aumid.empty())
	{
		_history.Remove(tag, group);
	}
	else
	{
		_history.Remove(tag, group, _win32Aumid);
	}
}

void DesktopNotificationHistoryCompat::RemoveGroup(std::wstring group)
{
	if (_win32Aumid.empty())
	{
		_history.RemoveGroup(group);
	}
	else
	{
		_history.RemoveGroup(group, _win32Aumid);
	}
}
