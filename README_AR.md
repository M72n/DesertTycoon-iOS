# Desert Tycoon - iOS Scaffold

## حالة العمل الحالية

تمت مزامنة أصول ملف APK المحلي إلى `ios-scaffold/Resources/LegacyAssets`، وتم توليد نسخ metadata مكبرة داخل `LegacyAssets/iphone-hd-upscaled` لملفات Sprite sheet بصيغة `.plist` بنسبة 1.875 حتى تطابق صور 1920x1920 عند توفرها. كما تم توليد خرائط كاملة من ملفات TMX داخل `ios-scaffold/Resources/GeneratedMaps` وربطها بمشهد SpriteKit تفاعلي بدلاً من واجهة العرض التجريبية.

تنبيه مهم: ملف `libgame.so` الموجود داخل APK هو مكتبة Android/ARM ولا يمكن تحويله مباشرة إلى iOS. الحفاظ على Gameplay بنسبة 100% يتطلب سورس Cocos2d-x/C++ الأصلي. في هذه الحزمة تم تجهيز مسار الأصول والـ workflow والواجهة الأولية، مع قاعدة صارمة أن أي تطوير حالي يكون بصرياً فقط ولا يغير منطق اللعبة.

هذه الحزمة تحتوي على مشروع iOS أولي مبني بـ SwiftUI و XcodeGen، مع أصول اللعبة المستخرجة من ملف APK القديم.

## ما تم تجهيزه

- واجهة SwiftUI متجاوبة تعمل على iPhone و iPad وتراعي الـ safe area والاتجاهات المختلفة.
- نسخ أصول اللعبة إلى `ios-scaffold/Resources/LegacyAssets`.
- وضع صور معاينة ثابتة في `ios-scaffold/Resources` لاستخدامها داخل الواجهة الأصلية.
- توليد AppIcon للأحجام المطلوبة في iOS و iPadOS.
- تحديث إعدادات البناء لاستخدام Swift 6 وحد أدنى iOS 17 مع إمكانية البناء عبر Xcode 26 أو أحدث.
- سكربت `ios-scaffold/build_ipa.sh` لأرشفة المشروع وتصدير IPA على macOS.

## ملاحظة مهمة

ملف APK لا يتحول إلى IPA بشكل مباشر. كود Android الموجود داخل `classes.dex` ومكتبات `.so` لا تعمل على iOS، لذلك هذا المشروع هو نقطة بداية لإعادة بناء اللعبة Native iOS وليس نسخة كاملة من منطق اللعبة الأصلي.

## قاعدة التطوير الحالية

الهدف هو الحفاظ على منطق اللعبة كما هو، وأن تكون التغييرات في هذه المرحلة بصرية فقط:

- تحميل الأصول المحسنة من `LegacyAssets/iphone-hd-upscaled` عند توفرها.
- الرجوع تلقائياً إلى أصول `LegacyAssets/iphone-hd` الأصلية عند غياب النسخة المحسنة.
- عرض الخريطة isometric عبر SpriteKit مع تحريك الكاميرا والزووم داخل حدود الخريطة.
- تشغيل حلقة بناء أولية من فئات APK الأصلية: سكني، أعمال، مجتمع، زراعة، طاقة، نفط.
- وضع البناء على الخريطة، انتظار اكتمال البناء، إنتاج موارد، وتحصيلها باللمس.
- عدم تغيير السرعات، الاقتصاد، المهام، أو قواعد المراحل بدون سورس اللعبة الأصلي والتحقق منه.

راجع:

```text
ios-scaffold/Resources/VISUAL_UPGRADE_POLICY.md
```

## بناء IPA على macOS

المتطلبات:

- macOS
- Xcode 26 أو أحدث
- حساب Apple Developer مضاف داخل Xcode
- XcodeGen

```bash
cd ios-scaffold
brew install xcodegen
chmod +x build_ipa.sh
DEVELOPMENT_TEAM=YOUR_TEAM_ID ./build_ipa.sh
```

سيظهر ملف IPA داخل:

```text
ios-scaffold/build/export
```

للتوزيع عبر TestFlight أو App Store، عدّل `ExportOptions.plist` وطريقة التوقيع حسب حساب Apple Developer ونوع التوزيع المطلوب.

## بناء IPA بدون Mac

للتثبيت السريع على iPhone من Windows، استخدم هذا الدليل أولاً:

```text
FASTEST_IPHONE_INSTALL_WINDOWS_AR.md
```

هذا المسار يبني IPA غير موقّع عبر GitHub Actions ثم يثبته عبر Sideloadly على Windows.

للبناء الموقّع بحساب Apple Developer، تمت إضافة GitHub Actions workflow:

```text
.github/workflows/ios-ipa.yml
```

اتبع الخطوات في:

```text
BUILD_WITHOUT_MAC_AR.md
```

هذا المسار يستخدم حساب Apple Developer الخاص بك عبر شهادات وGitHub Secrets، بدون مشاركة كلمة مرور Apple ID.

## الإعدادات الحالية

- Display Name: `desert-tycoon`
- Bundle ID: `ba.lum.deserttycoon`
- Version: `1.2.0`
- Build: `1821`
- Minimum iOS: `17.0`
- Build SDK المطلوب للرفع إلى App Store Connect في 2026: iOS 26 SDK عبر Xcode 26 أو أحدث
