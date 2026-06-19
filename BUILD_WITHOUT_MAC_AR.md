# بناء IPA بدون امتلاك Mac

لا تشارك كلمة مرور Apple ID مع أي شخص. استخدم GitHub Secrets أو خدمة CI مشابهة لحفظ الشهادات والمفاتيح.

## الخيار المجهز في هذا المشروع

أضفت workflow في:

```text
.github/workflows/ios-ipa.yml
```

بعد رفع المشروع إلى GitHub، افتح:

```text
Settings -> Secrets and variables -> Actions -> New repository secret
```

وأضف الأسرار التالية:

```text
DEVELOPMENT_TEAM
KEYCHAIN_PASSWORD
BUILD_CERTIFICATE_BASE64
P12_PASSWORD
BUILD_PROVISION_PROFILE_BASE64
```

اختياري عند وجود أكثر من شهادة توقيع في الحساب:

```text
CODE_SIGN_IDENTITY
```

ثم شغّل:

```text
Actions -> Build iOS IPA -> Run workflow
```

اختر `debugging` للتثبيت على جهازك المسجل في حساب Apple Developer، أو `app-store-connect` لتجهيز ملف مناسب لمسار TestFlight/App Store.

## إنشاء شهادة من Windows

ثبّت OpenSSL، ثم نفذ:

```powershell
openssl genrsa -out ios_signing.key 2048
openssl req -new -key ios_signing.key -out ios_signing.csr
```

افتح Apple Developer:

```text
Certificates, IDs & Profiles -> Certificates -> Add
```

اختر نوع الشهادة المناسب:

- Apple Development: للتثبيت التجريبي على أجهزة مسجلة.
- Apple Distribution: لـ TestFlight أو App Store.

ارفع ملف `ios_signing.csr`، ثم حمّل ملف الشهادة `.cer`.

حوّل الشهادة إلى `.p12`:

```powershell
openssl x509 -in ios_distribution.cer -inform DER -out ios_distribution.pem -outform PEM
openssl pkcs12 -export -inkey ios_signing.key -in ios_distribution.pem -out ios_distribution.p12 -name "iOS Signing"
```

كلمة المرور التي تختارها في أمر `pkcs12` ضعها في secret باسم:

```text
P12_PASSWORD
```

## إنشاء Provisioning Profile

من Apple Developer:

```text
Certificates, IDs & Profiles -> Identifiers
```

أنشئ App ID بنفس Bundle ID:

```text
ba.lum.deserttycoon
```

ثم:

```text
Profiles -> Add
```

اختر:

- iOS App Development إذا كان export method هو `debugging`.
- App Store إذا كان export method هو `app-store-connect`.

اربطه بالشهادة السابقة، ثم حمّل ملف `.mobileprovision`.

## تحويل الملفات إلى Base64 على Windows

لملف الشهادة:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("ios_distribution.p12")) | Set-Clipboard
```

الصق الناتج في GitHub secret:

```text
BUILD_CERTIFICATE_BASE64
```

لملف provisioning profile:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("profile.mobileprovision")) | Set-Clipboard
```

الصق الناتج في GitHub secret:

```text
BUILD_PROVISION_PROFILE_BASE64
```

## ملاحظات مهمة

- ملف IPA للتثبيت المباشر على iPhone يحتاج جهازك مسجلاً داخل Apple Developer إذا كان Development أو Ad Hoc.
- TestFlight يتطلب App Store Connect وتوقيع Distribution.
- هذا المشروع الحالي scaffold قابل للبناء، لكنه ليس نسخة كاملة من منطق لعبة Android الأصلية لأن كود APK لا يعمل على iOS مباشرة.
