/* Minimal SecTrustSettingsSetTrustSettings caller: `security add-trusted-cert` blocks on a
   GUI authorization prompt, this re-tries quietly from a launch agent. */
#include <CoreFoundation/CoreFoundation.h>
#include <Security/Security.h>
#include <stdio.h>

int main(int argc, char **argv) {
  CFMutableDataRef d = CFDataCreateMutable(NULL, 0);
  FILE *f = fopen(argv[1], "rb");
  if (!f) return 2;
  char buf[4096];
  size_t n;
  while ((n = fread(buf, 1, sizeof buf, f)) > 0) CFDataAppendBytes(d, (UInt8 *)buf, (CFIndex)n);
  fclose(f);
  SecCertificateRef cert = SecCertificateCreateWithData(NULL, d);
  CFRelease(d);
  if (!cert) return 3;
  OSStatus st = SecTrustSettingsSetTrustSettings(cert, kSecTrustSettingsDomainUser, NULL);
  CFRelease(cert);
  printf("status=%d\n", (int)st);
  return st == errSecSuccess ? 0 : 1;
}
