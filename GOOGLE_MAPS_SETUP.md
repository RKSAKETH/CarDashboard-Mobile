# Google Maps API Key - Step-by-Step Guide

## Quick Start (5 minutes)

### Step 1: Create Google Cloud Project
1. Go to https://console.cloud.google.com/
2. Sign in with your Google account
3. Click on the project dropdown (top left, next to "Google Cloud")
4. Click "NEW PROJECT"
5. Enter project name: "Speedometer App"
6. Click "CREATE"

### Step 2: Enable Maps SDK
1. From the left menu, click "APIs & Services" → "Library"
2. In the search box, type "Maps SDK for Android"
3. Click on "Maps SDK for Android"
4. Click the "ENABLE" button
5. Wait for it to enable (takes a few seconds)

### Step 3: Create API Key
1. From the left menu, click "APIs & Services" → "Credentials"
2. Click "+ CREATE CREDENTIALS" at the top
3. Select "API Key"
4. Your API key will be created and displayed in a popup
5. **IMPORTANT**: Copy this key immediately
6. It will look something like: `AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q`

### Step 4: (Optional but Recommended) Restrict API Key
1. In the popup, click "EDIT API KEY" or click on your newly created API key
2. Under "API restrictions":
   - Select "Restrict key"
   - Check "Maps SDK for Android"
3. Click "SAVE"

### Step 5: Update Your App
1. Open file: `android/app/src/main/AndroidManifest.xml`
2. Find the line with `YOUR_API_KEY_HERE`
3. Replace it with your actual API key:

**Before:**
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE"/>
```

**After:**
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q"/>
```

4. Save the file

### Step 6: Test Your App
```bash
flutter run
```

## Alternative: Testing Without Google Maps

If you want to test the app first without setting up Google Maps:
- The Gauge and Digital views will work perfectly
- Speed tracking, timer, and statistics will all work
- Map view will show "Waiting for GPS signal..." until you add the API key
- You can add the API key later when you're ready

## Free Tier Information

Google Maps Platform offers a free tier:
- $200 free credit per month
- For a personal speedometer app, you'll likely stay within the free tier
- No credit card required for development/testing
- You can set up billing limits to prevent charges

## Important Notes

### API Key Security
- Don't share your API key publicly
- Don't commit it to public GitHub repositories
- For production apps, use API key restrictions

### API Key Restrictions (Production)
For a production app, you should restrict your API key:

1. **Application restrictions**:
   - Select "Android apps"
   - Add package name: `com.example.app`
   - Add SHA-1 certificate fingerprint (get it with `keytool`)

2. **API restrictions**:
   - Select "Restrict key"
   - Only enable "Maps SDK for Android"

### Getting SHA-1 Fingerprint
For debug builds:
```bash
cd android
./gradlew signingReport
```
Or on Windows:
```bash
cd android
gradlew signingReport
```

Look for the SHA-1 under "Variant: debug"

## Troubleshooting

### "This API project is not authorized to use this API"
**Solution**: Make sure you enabled "Maps SDK for Android" in the API Library

### Map shows gray screen
**Solution**: 
1. Check API key is correctly added to AndroidManifest.xml
2. Verify "Maps SDK for Android" is enabled
3. Check internet connection
4. Try running the app after uninstalling previous version

### "API key not valid" error
**Solution**:
1. Verify you copied the complete API key
2. Check for extra spaces or quotes around the key
3. Make sure the key is inside the `android:value` attribute
4. If using restrictions, temporarily remove them to test

## Quick Reference

### Where to Get API Key
URL: https://console.cloud.google.com/apis/credentials

### Where to Enable Maps SDK
URL: https://console.cloud.google.com/apis/library/maps-android-backend.googleapis.com

### Where to Add API Key in Project
File: `android/app/src/main/AndroidManifest.xml`
Line: Search for "YOUR_API_KEY_HERE"

### Example API Key Format
```
AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q
```
- Starts with "AIza"
- 39 characters total
- Mix of letters, numbers

## Testing Checklist

✅ Created Google Cloud project  
✅ Enabled Maps SDK for Android  
✅ Created API key  
✅ Copied API key  
✅ Updated AndroidManifest.xml  
✅ Saved the file  
✅ Running `flutter run`  
✅ Testing on device/emulator  

## Need Help?

If you're still having issues:
1. Check the SETUP_NOTES.md file
2. Run `flutter doctor` to check your environment
3. Check the Android Studio logcat for specific error messages
4. Try running with `flutter run -v` for verbose output

## For iOS (Future)

If you plan to support iOS later:
1. Enable "Maps SDK for iOS" in API Library
2. Add the API key to `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_API_KEY")
```

---

**That's it!** You should now have a working Google Maps integration in your speedometer app. 🎉
