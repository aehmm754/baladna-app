# دليل التشغيل والنشر — تطبيق بلدنا (Baladna)

## 1. إعداد الخلفية وقاعدة البيانات (Supabase)
1. أنشئ مشروعاً جديداً على [Supabase](https://supabase.com).
2. افتح **SQL Editor** والصق محتوى `supabase/schema.sql` ثم اضغط **Run**.
3. فعّل **Phone Auth** من `Authentication > Providers > Phone` واربط مزود رسائل SMS يدعم سوريا (مثل Twilio أو Vonage أو بوابة SMS محلية/واتساب OTP عبر Supabase Edge Function).
4. انسخ `Project URL` و`anon public key` من `Project Settings > API`.

## 2. تشغيل تطبيق الموبايل محلياً (Flutter)
```bash
cd mobile_flutter
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## 3. تشغيل لوحة تحكم الإدارة (Next.js)
```bash
cd admin_nextjs
npm install
# أضف NEXT_PUBLIC_SUPABASE_URL و NEXT_PUBLIC_SUPABASE_ANON_KEY في .env.local
npm run dev
```

## 4. البناء والنشر على المتاجر (Google Play & App Store)
- **Google Play**:
  1. أنشئ مفتاح التوقيع `upload-keystore.jks` وعرّفه في `android/key.properties`.
  2. نفّذ: `flutter build appbundle --release` وارفع ملف `.aab` إلى Google Play Console.
- **App Store (iOS)**:
  1. على جهاز macOS (أو عبر GitHub Actions `macos-latest`) افتح `ios/Runner.xcworkspace` في Xcode واضبط `Bundle Identifier` و`Signing & Capabilities`.
  2. نفّذ: `flutter build ipa --release` وارفع الملف عبر **Transporter** إلى App Store Connect.
  3. للتجربة السريعة بدون حساب مطور آبل، استخدم ملف `baladna_unsigned.ipa` الناتج من `.github/workflows/build_mobile.yml` وثبّته عبر Sideloadly.
