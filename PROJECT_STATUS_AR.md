# حالة مشروع Desert Tycoon iOS

## ما تم إنجازه محلياً

- استخراج ومزامنة أصول APK من `C:\Users\USER\Downloads\desert-tycoon.apk` إلى `ios-scaffold/Resources/LegacyAssets`.
- وجود 117 ملفاً داخل `LegacyAssets` بعد إضافة ملفات metadata المكبرة.
- توليد 14 ملف `.plist` مكبر داخل `ios-scaffold/Resources/LegacyAssets/iphone-hd-upscaled` بنسبة 1.875.
- توليد خرائط كاملة من ملفات TMX داخل `ios-scaffold/Resources/GeneratedMaps`.
- استبدال واجهة SwiftUI التجريبية بمشهد SpriteKit تفاعلي يعرض خريطة isometric أصلية ويدعم تحريك الكاميرا والزووم داخل حدود الخريطة.
- إضافة loop لعب أولي مبني من إشارات APK: اختيار فئة بناء من السوق، وضع البناء على الخريطة، مؤقت إنشاء، إنتاج موارد، وتحصيل الموارد عند لمس البناء.
- إضافة حركة شخصية/جمل من frames الأصلية داخل `TravelingCamel-hd.plist`.
- إضافة موسيقى خلفية عند توفر `music_sound/BackgroundSound.mp3`.
- تحميل الأصول مع تفضيل النسخ المحسنة من `iphone-hd-upscaled` ثم الرجوع تلقائياً إلى أصول `iphone-hd` الأصلية.
- تحديث GitHub Actions workflow لبناء IPA غير موقع ونسخ أصول اللعبة داخل حزمة التطبيق.
- إضافة أدوات:
  - `tools/sync_apk_assets.ps1`
  - `tools/scale_cocos_plists.py`
  - `tools/render_tmx_maps.py`
  - `tools/report_sprite_frames.py`
  - `tools/extract_apk_gameplay_strings.py`
  - `tools/package_small_for_github.ps1`
  - `tools/package_metadata_for_github.ps1`

## حدود مهمة

لا يمكن تحويل `libgame.so` أو `classes.dex` من APK إلى iOS مباشرة. تم استخراج أسماء gameplay من `classes.dex` و`libgame.so` وظهر منها: `Business`, `Residential`, `Farm`, `Energy`, `Oil`, `Goals`, `Souk`, `Workers`, `Goods`, `Coins`, `Dinars`. النسخة الحالية تعيد بناء هذه الحلقة من الصفر في Swift/SpriteKit، لكنها ليست مطابقة 100% حتى يتم تفكيك منطق C++ الأصلي أو توفير السورس.

## طريقة الرفع الأسرع إلى GitHub

1. ارفع محتوى `DesertTycoon-iOS-GitHub-Upload-SMALL.zip` إلى المستودع لتحديث الكود والـ workflows.
2. إذا كانت ملفات metadata ناقصة في GitHub، ارفع محتوى `DesertTycoon-iOS-Metadata-Upload.zip`.
3. ارفع الصور والفيديو والصوتيات الكبيرة عن طريق GitHub Desktop أو `git` وليس كملف zip واحد من واجهة الويب.
4. شغل workflow:

```text
Actions -> Build Unsigned IPA for Sideloadly -> Run workflow
```

بعد انتهاء workflow، افتح صفحة التشغيل نفسها وحمل artifact باسم `DesertTycoon-unsigned-IPA`.
