# ReceiptVault AI

ReceiptVault AI is an offline-first Flutter application for organizing and
reporting on receipts. Stage 3 adds camera and photo-library capture, on-device
text recognition, editable scan review, and time-based spending reports.

## Stage 3 status

Completed:

- Three-step privacy-first onboarding
- Dashboard with monthly, all-time, and recent-receipt summaries
- Searchable receipt list with category filters
- Camera capture and photo-library receipt import
- On-device ML Kit text recognition for Latin-script receipts
- OCR extraction for merchant, date, amounts, and payment clues
- Fully editable scan review before saving
- Android interrupted-image recovery
- Manual receipt entry with payment details
- Offline purpose and category suggestions with Vancouver merchant aliases
- Required category confirmation before every manual save
- Receipt details, favorites, notes, amount breakdowns, and deletion
- Reports with weekly, monthly, yearly, all-time, average, and per-category sums
- Historical weekly, monthly, and yearly period breakdowns
- Excel export with a summary, complete receipt ledger, and yearly sheets
  organized into monthly sections
- Tap any weekly, monthly, or yearly period to open exactly its receipts
- Category drill-down into matching receipts
- Custom category creation
- Android and iOS Flutter scaffolds
- Green Material 3 light and dark themes
- Five-branch state-preserving navigation
- Raised center Scan action
- Drift database with foreign-key enforcement
- Integer-cent financial storage
- Receipt, receipt item, category, tag, receipt-tag, and app-setting tables
- 13 default categories
- Manual iCloud Drive and Google Drive backup and restore through the device's
  secure system file picker
- Database, OCR parsing, reporting, classification, money-formatting, and
  navigation tests

Receipt photos are reduced after text recognition: the shorter side is
scaled to 1280 pixels and saved as JPEG at quality 72, which is roughly 0.2 to
0.4 MB per receipt instead of several megabytes. The original capture is
deleted from temporary storage once the reduced copy is written. Settings shows
the space used by photos and can delete photos older than one year while
keeping every receipt record.

OCR and purpose recognition run on the device. Receipt photos are used for
recognition and are not uploaded by the app. Because receipt layouts vary,
every detected value remains editable and the category must be confirmed.

## Structure

```text
lib/
  app/                 App root, router, and themes
  core/                Shared constants, formatters, and interfaces
  data/
    local/             Drift schema and local database services
    providers/         Dependency providers
  features/            Feature-first presentation folders
  shared/              Reusable navigation and UI widgets
```

## Dependency compatibility

This project was resolved and tested with Flutter 3.44.8 and Dart 3.12.2.
Flutter currently pins versions of `meta`, `matcher`, and `test_api`, so these
compatible build-time versions are intentionally pinned:

- `drift` and `drift_dev`: 2.32.1
- `build_runner`: 2.15.1
- `image_picker`: 1.2.3
- `google_mlkit_text_recognition`: 0.16.0

Do not upgrade those packages independently. Run `flutter pub outdated`, then
upgrade the aligned set after Flutter's SDK pins support the newer analyzer.

## Generate database code

The generated Drift file is committed. Regenerate it after schema changes:

```bash
dart run build_runner build
```

## Validate

```bash
flutter pub get
flutter analyze
flutter test
```

## Run on Android

Install Android Studio and its Android SDK, create or start an emulator, and
then run:

```bash
flutter doctor
flutter doctor --android-licenses
flutter devices
flutter run -d <android-device-id>
```

Replace `<android-device-id>` with the ID printed by `flutter devices`.

## Run on iPhone from this Mac

The Flutter SDK lives at `~/development/flutter` and is on the PATH through
`~/.zshrc`. CocoaPods is installed as a user gem in `~/.gem/ruby/2.6.0/bin`,
which must also be on the PATH for iOS builds.

```bash
cd "/Users/narmandakhganbold/Desktop/app/Receipt Scanning Project"
export PATH="$HOME/development/flutter/bin:$HOME/.gem/ruby/2.6.0/bin:$PATH"
flutter pub get
open -a Simulator
flutter devices
flutter run -d <ios-device-id>
```

For a physical iPhone, open `ios/Runner.xcworkspace` in Xcode once to select
your development team and signing identity.

If `pod` fails with `uninitialized constant ActiveSupport::LoggerThreadSafeLevel::Logger`,
the fix is to pin `concurrent-ruby` to 1.3.4 in the user gem directory:

```bash
gem install concurrent-ruby -v 1.3.4 --user-install
gem uninstall concurrent-ruby -v 1.3.8 --user-install -x
```
