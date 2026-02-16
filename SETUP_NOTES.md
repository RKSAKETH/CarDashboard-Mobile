# IMPORTANT SETUP NOTES

## Before Running the App

### 1. Get Your Google Maps API Key (CRITICAL!)

The app will NOT show maps without a valid Google Maps API key. Follow these steps:

1. **Visit Google Cloud Console**: https://console.cloud.google.com/
2. **Create/Select Project**: Click on the project dropdown and create a new project or select an existing one
3. **Enable APIs**:
   - Navigate to "APIs & Services" → "Library"
   - Search for "Maps SDK for Android"
   - Click "Enable"
4. **Create API Key**:
   - Go to "APIs & Services" → "Credentials"
   - Click "Create Credentials" → "API Key"
   - Copy the generated API key
5. **Restrict API Key** (recommended):
   - Click on your API key to edit it
   - Under "Application restrictions", select "Android apps"
   - Add your package name: `com.example.app` (or change it to your desired package)

### 2. Update AndroidManifest.xml

**File**: `android/app/src/main/AndroidManifest.xml`

Find this line:
```xml
android:value="YOUR_API_KEY_HERE"/>
```

Replace `YOUR_API_KEY_HERE` with your actual API key:
```xml
android:value="AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"/>
```

### 3. Testing Without Google Maps (Alternative)

If you want to test the app without Google Maps initially:
- The Gauge and Digital views will work perfectly
- The Map view will show a "Waiting for GPS signal..." message
- All speed tracking, odometer, and timer features will work
- You can add the API key later

### 4. Running on Physical Device (Recommended)

For accurate GPS testing:
- Install the app on a physical Android device
- Enable location services on the device
- Grant location permissions when prompted
- Use the app outdoors or near a window for better GPS signal

### 5. Running on Emulator

To test on Android emulator:
- Open Android Studio AVD Manager
- Select your emulator and click "Extended Controls" (the "..." button)
- Navigate to "Location" tab
- You can send mock GPS coordinates here

## Quick Start Commands

```bash
# Navigate to the app directory
cd c:\Users\krish\Downloads\MAD_Project2\app

# Get dependencies (if not already done)
flutter pub get

# Run on connected device
flutter run

# Run on specific device
flutter devices  # List available devices
flutter run -d <device-id>

# Build APK for testing
flutter build apk --debug
```

## Package Name (Optional)

If you want to change the package name from `com.example.app`:

1. Update `android/app/build.gradle`:
   ```gradle
   defaultConfig {
       applicationId "com.yourcompany.speedometer"
       ...
   }
   ```

2. Update `AndroidManifest.xml` package name if needed

3. Update Google Maps API key restrictions to match

## Troubleshooting

### "Building with plugins requires symlink support" Error (Windows)
**Solution**:
1. Open Settings
2. Go to Update & Security → For Developers
3. Enable "Developer Mode"
4. Restart terminal
5. Run `flutter pub get` again

### GPS Not Working
**Solutions**:
- Make sure you're testing on a physical device
- Grant location permissions
- Enable high accuracy mode in device location settings
- Use the app outdoors

### Map Shows Blank Screen
**Solutions**:
- Verify Google Maps API key is correctly added
- Check that "Maps SDK for Android" is enabled in Google Cloud Console
- Ensure internet connection is available
- Check API key restrictions (try without restrictions first)

### Build Errors
**Solutions**:
```bash
flutter clean
flutter pub get
flutter run
```

## Color Customization

To change the app's color scheme, edit `lib/main.dart`:

```dart
theme: ThemeData(
  scaffoldBackgroundColor: const Color(0xFF1A1A1A),  // Background
  primaryColor: const Color(0xFF00FF00),              // Accent color
  // ... more theme settings
)
```

## Features Overview

✅ **Working Out of the Box**:
- Real-time speed tracking via GPS
- Odometer (total distance)
- Session timer
- Distance, avg speed, max speed stats
- Vehicle type switching (motorcycle, car, bicycle)
- Gauge view (analog speedometer)
- Digital view (7-segment display)
- Sidebar menu with all options
- History tracking (saved locally)
- Dark theme with green accents

⚠️ **Requires API Key**:
- Map view (Google Maps integration)

## Next Steps

1. ✅ Get Google Maps API key
2. ✅ Update AndroidManifest.xml with your API key
3. ✅ Run `flutter pub get` (already done)
4. ✅ Connect your Android device or start emulator
5. ✅ Run `flutter run`
6. ✅ Grant location permissions
7. ✅ Test the app!

## Support

If you encounter any issues:
1. Check this document first
2. Run `flutter doctor` to check your Flutter installation
3. Check the console for error messages
4. Make sure all permissions are granted

## App Structure

```
Speedometer App
├── Gauge View     → Analog speedometer with needle
├── Digital View   → LED-style digital display
├── Map View       → Google Maps with location
├── Bottom Nav     → Switch between views
├── Top Bar        → Menu, History, Premium
├── Sidebar        → Settings, Language, Share, etc.
├── Stats Cards    → Distance, Avg Speed, Max Speed
└── Start/Stop     → Begin/End tracking session
```

Enjoy your speedometer app! 🚀
