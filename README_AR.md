# تقرير ترحيل APK إلى iOS

> هذا التقرير لا يدّعي تحويل APK إلى IPA مباشرة. الهدف هو تحليل التطبيق وتوليد مشروع iOS أولي قابل للتطوير.

## الملخص

- اسم الملف: `desert-tycoon.apk`
- التطبيق المقترح: `desert-tycoon`
- Bundle ID: `ba.lum.deserttycoon`
- أقل إصدار iOS: `17.0`
- حزمة Android: `ba.lum.deserttycoon`
- النشاط الرئيسي: `ba.lum.deserttycoon.game.activity.GameActivity`
- درجة سهولة الترحيل: `56/100`

## الأطر المكتشفة

- Native Android / Unknown

## الصلاحيات وتحويل الخصوصية

- `android.permission.ACCESS_NETWORK_STATE` → `مراجعة يدوية`
- `android.permission.ACCESS_WIFI_STATE` → `مراجعة يدوية`
- `android.permission.BLUETOOTH` → `مراجعة يدوية`
- `android.permission.BLUETOOTH_ADMIN` → `مراجعة يدوية`
- `android.permission.GET_ACCOUNTS` → `NSContactsUsageDescription`
- `android.permission.INTERNET` → `مراجعة يدوية`
- `android.permission.READ_PHONE_STATE` → `ManualReviewRequired`
- `android.permission.RECEIVE_BOOT_COMPLETED` → `مراجعة يدوية`
- `android.permission.WAKE_LOCK` → `مراجعة يدوية`
- `android.permission.WRITE_EXTERNAL_STORAGE` → `NSPhotoLibraryAddUsageDescription`
- `android.permission.WRITE_SETTINGS` → `مراجعة يدوية`
- `ba.lum.deserttycoon.permission.C2D_MESSAGE` → `مراجعة يدوية`
- `com.android.vending.BILLING` → `مراجعة يدوية`
- `com.google.android.c2dm.permission.RECEIVE` → `مراجعة يدوية`

## ملاحظات مهمة

- الصلاحية android.permission.READ_PHONE_STATE تحتاج مراجعة وظيفية لأن لها بدائل مختلفة أو قيودًا على iOS.
- توجد مكتبات Native بصيغة .so: يجب استبدالها بمكتبات iOS أو XCFramework عند توفر المصدر.
- توقيع APK غير قابل للنقل إلى iOS؛ يلزم توقيع Apple Developer عند بناء IPA.
- يحتوي APK على classes.dex: كود Android لا يعمل على iOS ويجب إعادة بناء المنطق بلغات/أطر iOS.

## توصيات التنفيذ

- استخدم التقرير لتحديد الموارد القابلة للنقل، ثم أعد بناء واجهات المستخدم والمنطق الأساسي في مشروع iOS.
- راجع Info.plist وعبارات الخصوصية قبل الاختبار على جهاز حقيقي.
- أنشئ Bundle ID وSigning Team صحيحين من حساب Apple Developer قبل بناء IPA.
- الأطر المكتشفة: Native Android / Unknown. ابحث عن مشروع المصدر الأصلي لأن النقل من المصدر أدق بكثير من النقل من APK.
- استخرج الصور والخطوط وملفات JSON/HTML من res وassets وأعد تنظيمها داخل Assets.xcassets أو Bundle Resources.
- ابدأ بتصميم شاشة iOS المقابلة للـ Main Activity: ba.lum.deserttycoon.game.activity.GameActivity.

## الخطوة التالية على macOS

```bash
cd ios-scaffold
brew install xcodegen
./build_ipa.sh
```
