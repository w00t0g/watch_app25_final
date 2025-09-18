import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/watch.dart';

// Repository class for handling watch documents in Firestore
class WatchRepository {
  final _db = FirebaseFirestore.instance;

  // get a live stream of watches for a specific user
  Stream<QuerySnapshot> streamForUser(String uid) {
    return _db
        .collection('watches')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // add a new watch document
  Future<void> add(Watch w) {
    return _db.collection('watches').add(w.toCreateJson());
  }

  // delete a watch by its Firestore document id
  Future<void> deleteById(String id) {
    return _db.collection('watches').doc(id).delete();
  }
}
