# Firebase Google Sign-In Setup Guide (Web + Android)

## 🚨 Current Error Fix

Error: "Sign in failed. An unexpected error occurred. Please try again."

This is caused by incomplete OAuth configuration. Follow ALL steps below in order.

---

## ✅ Part 1: Firebase Console Configuration

### Step 1.1: Enable Google Sign-In Method
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** → **Sign-in method**
4. Click on **Google** provider
5. Toggle **Enable** to ON
6. **IMPORTANT**: Under "Web SDK configuration":
   - You'll see a **Web client ID** and **Web client secret**
   - **Keep this tab open** - you'll need these values

### Step 1.2: Add Authorized Domains
1. In Firebase Console: **Authentication** → **Settings** → **Authorized domains**
2. Ensure these domains are listed:
   - `localhost` (for development)
   - Your Firebase hosting domain (e.g., `your-app.web.app`)
   - Your Firebase app domain (e.g., `your-app.firebaseapp.com`)
3. Click **Add domain** if any are missing

---

## ✅ Part 2: Google Cloud Console Configuration (CRITICAL FOR WEB)

### Step 2.1: Access Google Cloud Console
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select the **same project** as your Firebase project (use the project dropdown)

### Step 2.2: Enable Required APIs
1. Navigate to **APIs & Services** → **Library**
2. Search for "**Google+ API**" or "**People API**"
3. Click **ENABLE** (if not already enabled)
4. **IMPORTANT**: After enabling, **wait 5-10 minutes** before testing

### Step 2.3: Configure OAuth Consent Screen
1. Go to **APIs & Services** → **OAuth consent screen**
2. If not configured:
   - **User Type**: Choose "External" (unless you have a Google Workspace)
   - Click **Create**
3. Fill in required fields:
   - **App name**: CarDashboard Mobile
   - **User support email**: Your email
   - **Developer contact email**: Your email
4. **Scopes**: Click "Add or Remove Scopes"
   - Add: `email`, `profile`, `openid`
5. **Test users** (if in Testing mode):
   - Click **Add Users**
   - Add your Google account email
6. Click **Save and Continue**

### Step 2.4: Configure OAuth Client ID
1. Go to **APIs & Services** → **Credentials**
2. Find the **OAuth 2.0 Client IDs** section
3. Click on the **Web client** (auto-created by Firebase)
4. **Authorized JavaScript origins**: Add these URIs:
   ```
   http://localhost
   http://localhost:5000
   http://localhost:8080
   https://your-project-id.web.app
   https://your-project-id.firebaseapp.com
   ```
5. **Authorized redirect URIs**: Add these URIs:
   ```
   http://localhost
   http://localhost:5000/__/auth/handler
   http://localhost:8080/__/auth/handler
   https://your-project-id.web.app/__/auth/handler
   https://your-project-id.firebaseapp.com/__/auth/handler
   ```
6. Click **Save**

### Step 2.5: Verify Web Client ID in Your Code
1. Copy the **Client ID** from the Web client credentials
2. Open `web/index.html`
3. Verify the meta tag has the correct Client ID:
   ```html
   <meta name="google-signin-client_id" content="YOUR_CLIENT_ID_HERE.apps.googleusercontent.com">
   ```
4. **Currently in your file**: `723962598173-a8qvlla88l182d7vff8mtnvi0rigpn7e.apps.googleusercontent.com`
5. **Verify this matches** the Web client ID in Google Cloud Console

---

## ✅ Part 3: Android Configuration (SHA-1 Fingerprint)

### Step 3.1: Generate SHA-1
1. Open terminal in your project root
2. Run:
   ```powershell
   cd android
   .\gradlew signingReport
   cd ..
   ```
3. Copy the **SHA1** from the **debug** variant (looks like `AA:BB:CC:DD:...`)

### Step 3.2: Add SHA-1 to Firebase
1. Go to Firebase Console
2. Navigate to **Project Settings** (gear icon) → **General**
3. Scroll to **Your apps** section
4. Find your **Android app**
5. Click **Add fingerprint**
6. Paste the SHA-1 you copied
7. Click **Save**
8. **Re-download** `google-services.json` and replace in `android/app/`

---

## ✅ Part 4: Test After Configuration

### Wait Period
**IMPORTANT**: After making changes in Google Cloud Console, **wait 5-10 minutes** before testing. API changes take time to propagate.

### Test on Web
```powershell
flutter clean
flutter pub get
flutter run -d chrome
```

**Expected behavior**:
1. App loads showing login screen
2. Click "Sign in with Google"
3. Popup opens with Google account selection
4. After selecting account, you're signed in

**If popup closes immediately**:
- Check browser console (F12) for errors
- Verify all Authorized JavaScript origins are correct
- Clear browser cache and try again
- Try in Incognito mode

### Test on Android
```powershell
flutter run -d android
```

**Expected behavior**:
1. App installs and shows login screen
2. Click "Sign in with Google"
3. Native account picker appears
4. After selecting account, you're signed in

**If sign-in fails with "sign_in_failed"**:
- 99% of the time this is SHA-1 mismatch
- Verify SHA-1 in Firebase matches `gradlew signingReport` output
- If using release build, add **Release SHA-1** as well

---

## 🔧 Quick Checklist

Before running the app, verify:

- [ ] Google sign-in enabled in Firebase Console
- [ ] Google+ API or People API enabled in Google Cloud Console
- [ ] OAuth consent screen configured with test users
- [ ] Web client ID has correct Authorized JavaScript origins
- [ ] Web client ID has correct Authorized redirect URIs
- [ ] Client ID in `web/index.html` matches Google Cloud Console
- [ ] SHA-1 added to Firebase for Android
- [ ] Waited 5-10 minutes after enabling APIs
- [ ] `flutter clean` and `flutter pub get` executed

---

## 🐛 Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| Popup closes immediately | Missing authorized domains | Add `localhost` to Firebase authorized domains |
| "idToken can't be provided" | OAuth not configured | Complete OAuth consent screen setup |
| "API not enabled" | Google+ API disabled | Enable Google+ API and wait 5-10 minutes |
| "sign_in_failed" (Android) | SHA-1 mismatch | Re-run `gradlew signingReport` and verify |
| Cross-Origin error | Missing redirect URIs | Add `__/auth/handler` URIs to OAuth client |

---

## 📞 Still Having Issues?

1. Check Firebase Console → Authentication → Users
   - If users appear here after "failed" sign-in, it's a navigation issue
2. Check browser console (F12) for specific error codes
3. Verify your Firebase project is on the Blaze (pay-as-you-go) plan if using advanced features
4. Try signing in with a different Google account

---

## 🎯 Your Current Configuration Status

Based on your files:
- ✅ `firebase_options.dart`: Should be generated via `flutterfire configure`
- ✅ `web/index.html`: Web Client ID added
- ✅ `google-services.json`: Present in android/app/
- ⚠️ **Next step**: Complete OAuth consent screen in Google Cloud Console
- ⚠️ **Next step**: Add Authorized JavaScript origins
- ⚠️ **Next step**: Wait 5-10 minutes after enabling APIs

---

Generated: 2026-02-17
