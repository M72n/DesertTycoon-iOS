# حالة مشروع Desert Tycoon iOS

## ما تم إنجازه محلياً

- استخراج ومزامنة أصول APK من `C:\Users\USER\Downloads\desert-tycoon.apk` إلى `ios-scaffold/Resources/LegacyAssets`.
- وجود 117 ملفاً داخل `LegacyAssets` بعد إضافة ملفات metadata المكبرة.
- توليد 14 ملف `.plist` مكبر داخل `ios-scaffold/Resources/LegacyAssets/iphone-hd-upscaled` بنسبة 1.875.
- تحديث واجهة SwiftUI لتفضيل الأصول المحسنة من `iphone-hd-upscaled` ثم الرجوع تلقائياً إلى أصول `iphone-hd` الأصلية.
- تحديث GitHub Actions workflow لبناء IPA غير موقع ونسخ أصول اللعبة داخل حزمة التطبيق.
- إضافة أدوات:
  - `tools/sync_apk_assets.ps1`
  - `tools/scale_cocos_plists.py`
  - `tools/package_small_for_github.ps1`
  - `tools/package_metadata_for_github.ps1`

## حدود مهمة

لا يمكن تحويل `libgame.so` أو `classes.dex` من APK إلى iOS مباشرة. إذا كان المطلوب هو نفس الـ Gameplay بنسبة 100%، فيجب توفير سورس اللعبة الأصلي Cocos2d-x/C++ أو إعادة بناء المنطق من الصفر ومقارنته بالنسخة الأصلية.

## طريقة الرفع الأسرع إلى GitHub

1. ارفع محتوى `DesertTycoon-iOS-GitHub-Upload-SMALL.zip` إلى المستودع لتحديث الكود والـ workflows.
2. إذا كانت ملفات metadata ناقصة في GitHub، ارفع محتوى `DesertTycoon-iOS-Metadata-Upload.zip`.
3. ارفع الصور والفيديو والصوتيات الكبيرة عن طريق GitHub Desktop أو `git` وليس كملف zip واحد من واجهة الويب.
4. شغل workflow:

```text
Actions -> Build Unsigned IPA for Sideloadly -> Run workflow
```

بعد انتهاء workflow، افتح صفحة التشغيل نفسها وحمل artifact باسم `DesertTycoon-unsigned-IPA`.
