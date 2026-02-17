import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to handle Cloud Firestore operations
class FirestoreService {
  // Singleton instance
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get reference to users collection
  CollectionReference get usersCollection => _firestore.collection('users');

  /// Get reference to trips collection
  CollectionReference get tripsCollection => _firestore.collection('trips');

  // ==================== USER OPERATIONS ====================

  /// Create or update user profile in Firestore
  Future<void> createOrUpdateUserProfile({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) async {
    try {
      await usersCollection.doc(uid).set({
        'email': email,
        'displayName': displayName ?? '',
        'photoUrl': photoUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: true will update existing fields
    } catch (e) {
      print('Error creating/updating user profile: $e');
      rethrow;
    }
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await usersCollection.doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      rethrow;
    }
  }

  /// Stream user profile data (real-time updates)
  Stream<DocumentSnapshot> getUserProfileStream(String uid) {
    return usersCollection.doc(uid).snapshots();
  }

  // ==================== TRIP OPERATIONS ====================

  /// Save a trip/session to Firestore
  Future<String> saveTrip({
    required String userId,
    required double distance,
    required double maxSpeed,
    required double avgSpeed,
    required int durationSeconds,
    required String vehicleType,
  }) async {
    try {
      DocumentReference docRef = await tripsCollection.add({
        'userId': userId,
        'distance': distance,
        'maxSpeed': maxSpeed,
        'avgSpeed': avgSpeed,
        'durationSeconds': durationSeconds,
        'vehicleType': vehicleType,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print('Trip saved with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error saving trip: $e');
      rethrow;
    }
  }

  /// Get all trips for a user
  Future<List<Map<String, dynamic>>> getUserTrips(String userId) async {
    try {
      QuerySnapshot querySnapshot = await tripsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      print('Error getting user trips: $e');
      rethrow;
    }
  }

  /// Stream user trips (real-time updates)
  Stream<QuerySnapshot> getUserTripsStream(String userId) {
    return tripsCollection
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Get trip statistics for a user
  Future<Map<String, dynamic>> getTripStatistics(String userId) async {
    try {
      QuerySnapshot querySnapshot = await tripsCollection
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {
          'totalTrips': 0,
          'totalDistance': 0.0,
          'totalDuration': 0,
          'maxSpeed': 0.0,
          'avgSpeed': 0.0,
        };
      }

      double totalDistance = 0;
      int totalDuration = 0;
      double maxSpeed = 0;
      double totalAvgSpeed = 0;

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        totalDistance += (data['distance'] ?? 0.0) as double;
        totalDuration += (data['durationSeconds'] ?? 0) as int;
        maxSpeed = maxSpeed > (data['maxSpeed'] ?? 0.0) 
            ? maxSpeed 
            : (data['maxSpeed'] ?? 0.0) as double;
        totalAvgSpeed += (data['avgSpeed'] ?? 0.0) as double;
      }

      return {
        'totalTrips': querySnapshot.docs.length,
        'totalDistance': totalDistance,
        'totalDuration': totalDuration,
        'maxSpeed': maxSpeed,
        'avgSpeed': querySnapshot.docs.isNotEmpty 
            ? totalAvgSpeed / querySnapshot.docs.length 
            : 0.0,
      };
    } catch (e) {
      print('Error getting trip statistics: $e');
      rethrow;
    }
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    try {
      await tripsCollection.doc(tripId).delete();
      print('Trip deleted: $tripId');
    } catch (e) {
      print('Error deleting trip: $e');
      rethrow;
    }
  }

  // ==================== BATCH OPERATIONS ====================

  /// Delete all trips for a user
  Future<void> deleteAllUserTrips(String userId) async {
    try {
      QuerySnapshot querySnapshot = await tripsCollection
          .where('userId', isEqualTo: userId)
          .get();

      WriteBatch batch = _firestore.batch();
      
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('All trips deleted for user: $userId');
    } catch (e) {
      print('Error deleting all trips: $e');
      rethrow;
    }
  }

  // ==================== QUERY EXAMPLES ====================

  /// Get trips within a date range
  Future<List<Map<String, dynamic>>> getTripsInDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      QuerySnapshot querySnapshot = await tripsCollection
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: startDate)
          .where('timestamp', isLessThanOrEqualTo: endDate)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      print('Error getting trips in date range: $e');
      rethrow;
    }
  }

  /// Get top speed trips
  Future<List<Map<String, dynamic>>> getTopSpeedTrips({
    required String userId,
    int limit = 10,
  }) async {
    try {
      QuerySnapshot querySnapshot = await tripsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('maxSpeed', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data() as Map<String, dynamic>,
              })
          .toList();
    } catch (e) {
      print('Error getting top speed trips: $e');
      rethrow;
    }
  }
}
