#include "file_associations.h"

#include <windows.h>

#include <string>
#include <vector>

namespace {

std::wstring GetExecutablePath() {
  wchar_t buffer[MAX_PATH];
  DWORD length = GetModuleFileNameW(nullptr, buffer, MAX_PATH);
  if (length == 0 || length == MAX_PATH) {
    return L"";
  }
  return std::wstring(buffer, length);
}

std::wstring GetExecutableName(const std::wstring& path) {
  const size_t pos = path.find_last_of(L"\\/");
  if (pos == std::wstring::npos || pos + 1 >= path.size()) {
    return path;
  }
  return path.substr(pos + 1);
}

void RegisterSupportedTypes(const std::wstring& exe_name) {
  const std::wstring supported_key =
      L"Software\\Classes\\Applications\\" + exe_name + L"\\SupportedTypes";
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, supported_key.c_str(), 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }

  const std::vector<std::wstring> extensions = {
      L".mp3",  L".flac", L".aac",  L".wav", L".ogg",  L".m4a", L".opus",
      L".wma",  L".aiff", L".alac", L".dsf", L".ape",  L".wv",  L".mka",
  };

  for (const auto& ext : extensions) {
    RegSetValueExW(key, ext.c_str(), 0, REG_SZ, nullptr, 0);
  }

  RegCloseKey(key);
}

void RegisterOpenCommand(const std::wstring& exe_name,
                         const std::wstring& exe_path) {
  const std::wstring command_key =
      L"Software\\Classes\\Applications\\" + exe_name +
      L"\\shell\\open\\command";
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, command_key.c_str(), 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }

  const std::wstring command = L"\"" + exe_path + L"\" \"%1\"";
  RegSetValueExW(key, nullptr, 0, REG_SZ,
                 reinterpret_cast<const BYTE*>(command.c_str()),
                 static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));

  RegCloseKey(key);
}

void RegisterFriendlyName(const std::wstring& exe_name) {
  const std::wstring app_key =
      L"Software\\Classes\\Applications\\" + exe_name;
  HKEY key = nullptr;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, app_key.c_str(), 0, nullptr, 0,
                      KEY_SET_VALUE, nullptr, &key, nullptr) != ERROR_SUCCESS) {
    return;
  }

  const std::wstring friendly_name = L"Misuzu Music";
  RegSetValueExW(key, L"FriendlyAppName", 0, REG_SZ,
                 reinterpret_cast<const BYTE*>(friendly_name.c_str()),
                 static_cast<DWORD>((friendly_name.size() + 1) * sizeof(wchar_t)));
  RegCloseKey(key);
}

}  // namespace

void RegisterFileAssociations() {
  const std::wstring exe_path = GetExecutablePath();
  if (exe_path.empty()) {
    return;
  }
  const std::wstring exe_name = GetExecutableName(exe_path);
  if (exe_name.empty()) {
    return;
  }

  RegisterOpenCommand(exe_name, exe_path);
  RegisterSupportedTypes(exe_name);
  RegisterFriendlyName(exe_name);
}
