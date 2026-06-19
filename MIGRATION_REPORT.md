# أسرع طريقة لتثبيت اللعبة على iPhone من Windows

هذه الطريقة لا تحتاج Mac ولا شهادات Apple Developer في البداية. الفكرة:

```text
GitHub Actions يبني IPA غير موقّع
Sideloadly على Windows يوقّع IPA بحساب Apple ID ويثبته على iPhone
```

## 1. جهّز ملف الرفع

افتح PowerShell داخل مجلد المشروع وشغّل:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\package_small_for_github.ps1
```

سيظهر ملف:

```text
DesertTycoon-iOS-GitHub-Upload-SMALL.zip
```

## 2. ارفع المشروع إلى GitHub

1. افتح [github.com/new](https://github.com/new).
2. أنشئ Repository جديد باسم `DesertTycoon-iOS`.
3. فك ضغط ملف `DesertTycoon-iOS-GitHub-Upload-SMALL.zip`.
4. من صفحة Repository اختر `Add file -> Upload files`.
5. اسحب كل الملفات والمجلدات التي خرجت من ZIP، ثم اضغط `Commit changes`.

تأكد أن المجلد التالي موجود داخل GitHub:

```text
.github/workflows/ios-unsigned-ipa.yml
```

## 3. ابنِ IPA

من GitHub:

```text
Actions -> Build Unsigned IPA for Sideloadly -> Run workflow
```

بعد انتهاء البناء:

```text
Artifacts -> DesertTycoon-unsigned-IPA
```

حمّل ملف `DesertTycoon-unsigned.ipa`.

## 4. ثبّت IPA على iPhone من Windows

1. حمّل Sideloadly من [sideloadly.io](https://sideloadly.io/index.html).
2. ثبّت iTunes من Apple إذا طلبه Sideloadly.
3. وصّل iPhone بالكمبيوتر عبر USB واضغط Trust على الهاتف.
4. افتح Sideloadly.
5. اسحب ملف `DesertTycoon-unsigned.ipa`.
6. أدخل Apple ID الخاص بك.
7. اضغط Start.

إذا ظهر التطبيق على iPhone لكن لم يفتح:

```text
Settings -> General -> VPN & Device Management
```

ثم اعمل Trust لحساب Apple ID.

## ملاحظات مهمة

- بحساب Apple ID مجاني، التطبيق غالباً يعمل لمدة 7 أيام ثم يحتاج إعادة توقيع عبر Sideloadly.
- بحساب Apple Developer مدفوع، المدة أطول.
- هذه الطريقة مناسبة للتجربة على جهازك، وليست للنشر في App Store.
- اللعبة الحالية ما زالت نسخة iOS أولية وليست تحويل كامل لمنطق APK الأصلي.
