/* Test-only adapter: create a hard link without changing access rules. */
#ifdef _WIN32
#include <windows.h>
int moonrdiff_check_hardlink(const wchar_t *existing, const wchar_t *created) {
  return CreateHardLinkW(created, existing, NULL) ? 0 : (int)GetLastError();
}
#else
#include <errno.h>
#include <unistd.h>
int moonrdiff_check_hardlink(const char *existing, const char *created) {
  return link(existing, created) == 0 ? 0 : errno;
}
#endif
