# Speedometer GPS App

A fully functional GPS-based speedometer app built with Flutter that matches the exact design specifications.

## Features

### Core Features
- **Real-time Speed Tracking**: Live GPS-based speed measurement in km/h
- **Multiple View Modes**:
  - **Gauge View**: Analog speedometer with needle animation
  - **Digital View**: 7-segment LED-style digital display
  - **Map View**: Google Maps integration showing current location
- **GPS Status**: Real-time GPS signal and satellite count
- **Odometer**: Tracks total distance traveled
- **Timer/Stopwatch**: Session duration tracking
- **Statistics**: Distance, Average Speed, and Max Speed tracking

### Vehicle Types
Switch between:
- 🏍️ Motorcycle
- 🚗 Car
- 🚴 Bicycle (Cycling)

### Sidebar Menu
- ⚙️ **Settings**: App configuration
- 🌐 **Language**: Multi-language support
- ⭐ **Rate Us**: Rate on app stores
- 💬 **Feedback**: Send feedback
- 📤 **Share with Friends**: Share the app
- 🔒 **Privacy Policy**: View privacy policy
- 👑 **Premium**: Upgrade to premium features

### Additional Features
- 📜 **History**: View past trip sessions
- Dark theme with vibrant green accents
- Bottom navigation for easy switching between views

## Setup Instructions

### 1. Prerequisites
- Flutter SDK (3.35.0 or higher)
- Android SDK
- Google Maps API Key

### 2. Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the following APIs:
   - Maps SDK for Android
   - Maps SDK for iOS (if targeting iOS)
4. Create credentials (API Key)
5. Copy your API key

### 3. Configure Google Maps API Key

#### For Android:
Open `android/app/src/main/AndroidManifest.xml` and replace `YOUR_API_KEY_HERE` with your actual API key:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY"/>
```

#### For iOS (if needed):
Open `ios/Runner/AppDelegate.swift` and add:

```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_ACTUAL_API_KEY")
```

### 4. Install Dependencies

```bash
flutter pub get
```

### 5. Enable Developer Mode (Windows)

If you're on Windows and encounter symlink issues:
1. Open Settings → Update & Security → For Developers
2. Enable Developer Mode
3. Run `flutter pub get` again

### 6. Run the App

```bash
flutter run
```

## Permissions

The app requires the following permissions:
- **Location (GPS)**: For real-time speed and position tracking
- **Internet**: For loading map tiles

## Color Scheme

- **Background**: `#1A1A1A` (Dark)
- **Surface**: `#2A2A2A` (Lighter dark)
- **Primary/Accent**: `#00FF00` (Bright green)
- **Text**: White and white70 for secondary text
- **Premium Icon**: `#FFD700` (Gold)

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/
│   └── home_screen.dart      # Main screen with all functionality
├── widgets/
│   ├── gauge_view.dart       # Analog speedometer view
│   ├── digital_view.dart     # Digital 7-segment display view
│   ├── map_view.dart         # Google Maps view
│   └── app_drawer.dart       # Sidebar menu
├── models/
│   └── speed_data.dart       # Data models
└── services/
    ├── location_service.dart # GPS tracking service
    └── history_service.dart  # Session history storage
```

## Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  geolocator: ^13.0.2           # GPS tracking
  google_maps_flutter: ^2.9.0   # Map view
  permission_handler: ^11.3.1   # Location permissions
  shared_preferences: ^2.3.3    # Local storage
  intl: ^0.19.0                # Date formatting
  url_launcher: ^6.3.1          # Launch URLs
  share_plus: ^10.1.3           # Share functionality
```

## How to Use

1. **Grant Permissions**: When you first open the app, grant location permissions
2. **Wait for GPS**: The app will connect to GPS satellites
3. **Select Vehicle Type**: Choose your vehicle type from the dropdown
4. **Press START**: Begin tracking your trip
5. **View Stats**: Switch between Gauge, Digital, and Map views
6. **Press STOP**: End your session and save the trip history

## Troubleshooting

### GPS Not Working
- Ensure location permissions are granted
- Make sure GPS is enabled on your device
- Try using the app outdoors for better GPS signal

### Map Not Loading
- Verify your Google Maps API key is correctly configured
- Ensure the Maps SDK is enabled in Google Cloud Console
- Check your internet connection

### Build Issues
- Run `flutter clean` then `flutter pub get`
- Make sure all dependencies are properly installed
- On Windows, ensure Developer Mode is enabled

## Future Enhancements

- Export trip history to CSV
- Custom themes
- Speed alerts
- Advanced analytics
- Offline map support

## License

This project is created for educational purposes.

## Credits

Built with Flutter ❤️
