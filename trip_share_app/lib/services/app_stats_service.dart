import 'package:cloud_firestore/cloud_firestore.dart';

class AppStatsService {
  static const int completedTourSeed = 127;
  static const String globalStatsDocument = 'global';

  final FirebaseFirestore _firestore;

  AppStatsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get globalStatsRef =>
      _firestore.collection('app_stats').doc(globalStatsDocument);

  Stream<int> watchCompletedTourCount() {
    return globalStatsRef.snapshots().map(
      (snapshot) => completedTourCountFrom(snapshot.data()),
    );
  }

  static int completedTourCountFrom(Map<String, dynamic>? data) {
    final rawValue = data?['completedTourCount'];
    final storedCount = rawValue is num
        ? rawValue.toInt()
        : int.tryParse(rawValue?.toString() ?? '');
    if (storedCount == null || storedCount < completedTourSeed) {
      return completedTourSeed;
    }
    return storedCount;
  }
}
