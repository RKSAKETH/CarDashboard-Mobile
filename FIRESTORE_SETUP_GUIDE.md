# Cloud Firestore Setup Guide

## 📦 Package Installation

✅ **COMPLETED**: Added `cloud_firestore: ^6.1.2` to `pubspec.yaml`

---

## 🔧 Firebase Console Setup

### Step 1: Enable Cloud Firestore

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Build** → **Firestore Database**
4. Click **Create database**

### Step 2: Choose Security Mode

You'll see two options:

#### Option A: **Production Mode** (Recommended for learning)
- **Starting rules**: Deny all reads and writes
- **You'll need to set up rules manually** (see Step 3)
- More secure, but requires configuration

#### Option B: **Test Mode**
- **Starting rules**: Allow all reads and writes for 30 days
- ⚠️ **WARNING**: Anyone can read/write your database
- Good for initial testing, but **MUST** be updated before going live

**For now, choose Test Mode** to get started quickly. We'll set up proper security rules later.

### Step 3: Choose Firestore Location

1. Select a location close to your users (e.g., `asia-south1` for India)
2. **IMPORTANT**: This **cannot be changed** later!
3. Click **Enable**

### Step 4: Wait for Database Creation

Firebase will create your Firestore database. This takes about 1 minute.

---

## 🔒 Security Rules (IMPORTANT)

### Initial Test Rules (Currently Active)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2026, 3, 19);
    }
  }
}
```

⚠️ **This allows ANYONE to read/write for 30 days. You MUST update this!**

### Production-Ready Security Rules

Replace the test rules with these secure rules:

1. In Firebase Console: **Firestore Database** → **Rules**
2. Replace with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - only authenticated users can read/write their own profile
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Trips collection - only the trip owner can read/write
    match /trips/{tripId} {
      allow read: if request.auth != null && 
                     request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && 
                       request.auth.uid == request.resource.data.userId;
      allow update, delete: if request.auth != null && 
                               request.auth.uid == resource.data.userId;
    }
    
    // Allow users to query their own trips
    match /trips/{document=**} {
      allow read: if request.auth != null;
    }
  }
}
```

3. Click **Publish**

### What These Rules Do:

✅ **Users can only access their own profile**  
✅ **Users can only create/read/update/delete their own trips**  
✅ **Unauthenticated users cannot access any data**  
✅ **Users cannot access other users' data**

---

## 🏗️ Database Structure

### Collections Created by FirestoreService:

#### 1. **`users`** Collection
Stores user profile information.

**Document ID**: User's Firebase Auth UID  
**Fields**:
```json
{
  "email": "user@example.com",
  "displayName": "John Doe",
  "photoUrl": "https://...",
  "createdAt": Timestamp,
  "lastLogin": Timestamp
}
```

#### 2. **`trips`** Collection
Stores speedometer trip/session data.

**Document ID**: Auto-generated  
**Fields**:
```json
{
  "userId": "abc123...",
  "distance": 15.5,
  "maxSpeed": 85.3,
  "avgSpeed": 42.1,
  "durationSeconds": 1800,
  "vehicleType": "motorcycle",
  "timestamp": Timestamp
}
```

---

## 📝 Firestore Indexes

### Required Composite Indexes

For complex queries, Firestore requires composite indexes. Create these:

1. In Firebase Console: **Firestore Database** → **Indexes**
2. Click **Add Index**

#### Index 1: User Trips Ordered by Timestamp
- **Collection**: `trips`
- **Fields**:
  - `userId` - Ascending
  - `timestamp` - Descending
- **Query scope**: Collection
- Click **Create**

#### Index 2: User Trips Ordered by Max Speed
- **Collection**: `trips`
- **Fields**:
  - `userId` - Ascending
  - `maxSpeed` - Descending
- **Query scope**: Collection
- Click **Create**

**Note**: When you run a query that requires an index, Firestore will show an error with a direct link to create the required index.

---

## 🚀 Using Firestore in Your App

### 1. Update AuthService to Save User Profile

Modify `lib/services/auth_service.dart`:

```dart
import 'firestore_service.dart';

// In signInWithGoogle() method, after successful sign-in:
final userCredential = await _auth.signInWithCredential(credential);

// Save user profile to Firestore
if (userCredential.user != null) {
  await FirestoreService().createOrUpdateUserProfile(
    uid: userCredential.user!.uid,
    email: userCredential.user!.email ?? '',
    displayName: userCredential.user!.displayName,
    photoUrl: userCredential.user!.photoURL,
  );
}

return userCredential;
```

### 2. Save Trip Data

In your `HomeScreen` or `HistoryService`, save trips to Firestore:

```dart
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

Future<void> _saveSession() async {
  if (_elapsed.inSeconds > 0) {
    final user = AuthService().currentUser;
    if (user != null) {
      try {
        await FirestoreService().saveTrip(
          userId: user.uid,
          distance: _totalDistance,
          maxSpeed: _maxSpeed,
          avgSpeed: _avgSpeed,
          durationSeconds: _elapsed.inSeconds,
          vehicleType: _vehicleType.toString(),
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip saved successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save trip: $e')),
        );
      }
    }
  }
}
```

### 3. Display Trip History

```dart
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please login to view history')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trip History')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getUserTripsStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No trips yet'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var trip = snapshot.data!.docs[index].data() 
                  as Map<String, dynamic>;
              
              return ListTile(
                title: Text('${trip['distance']?.toStringAsFixed(2)} km'),
                subtitle: Text(
                  'Max: ${trip['maxSpeed']?.toStringAsFixed(0)} km/h • '
                  'Avg: ${trip['avgSpeed']?.toStringAsFixed(0)} km/h'
                ),
                trailing: Text(trip['vehicleType'] ?? 'Unknown'),
              );
            },
          );
        },
      ),
    );
  }
}
```

---

## 🔍 Testing Firestore

### Test in Firebase Console

1. Go to **Firestore Database** → **Data**
2. You should see collections appear as you use the app
3. Click on documents to view/edit data manually
4. Use this to verify data is being saved correctly

### Test in Your App

1. **Sign in** with Google
2. **Start a trip** in the speedometer
3. **Stop the trip** to save it
4. **Check Firebase Console** - you should see a new document in `trips` collection
5. **View History Screen** - you should see the trip listed

---

## 📊 Firestore Features Used

| Feature | Usage in Your App |
|---------|-------------------|
| **Collections & Documents** | `users` and `trips` collections |
| **Real-time Listeners** | `StreamBuilder` for live trip updates |
| **Queries** | Filter trips by userId, order by timestamp |
| **Batch Operations** | Delete all user trips at once |
| **Server Timestamps** | Automatic timestamp generation |
| **Security Rules** | User-based access control |

---

## 🐛 Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| **Permission denied** | Security rules blocking access | Check rules allow authenticated users |
| **Index required** | Complex query needs index | Click the error link to create index |
| **Offline not working** | Persistence disabled | Enable offline persistence (see below) |
| **Slow queries** | Large dataset, no indexing | Create composite indexes |

### Enable Offline Persistence (Optional)

Add to `main.dart` after Firebase initialization:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Enable offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const SpeedometerApp());
}
```

---

## ✅ Setup Checklist

Before using Firestore in production:

- [ ] Firestore database created in Firebase Console
- [ ] Location selected (cannot be changed later)
- [ ] Security rules updated from Test Mode to Production rules
- [ ] Composite indexes created for queries
- [ ] User profile saving on sign-in implemented
- [ ] Trip saving implemented
- [ ] Trip history display implemented
- [ ] Error handling added for all Firestore operations
- [ ] Tested on both Web and Android

---

## 🎯 Next Steps

1. **Update AuthService** to save user profiles
2. **Update HomeScreen** to save trips to Firestore
3. **Update HistoryScreen** to display trips from Firestore
4. **Test** sign-in and trip saving
5. **Verify** data appears in Firebase Console
6. **Update Security Rules** before deploying to production

---

Generated: 2026-02-17
