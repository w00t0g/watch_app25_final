import 'package:cloud_firestore/cloud_firestore.dart';

// Simple data model for a Watch
class Watch {
  final String brand;          // required: watch brand
  final String model;          // required: watch model
  final String? reference;     // optional: reference number
  final String? movement;      // optional: movement / caliber
  final String? photoUrl;      // optional: main photo url
  final Timestamp? purchaseDate; // optional: date of purchase
  final String userId;         // required: owner (Firebase user id)

  Watch({
    required this.brand,
    required this.model,
    this.reference,
    this.movement,
    this.photoUrl,
    this.purchaseDate,
    required this.userId,
  });

  // convert to Firestore JSON (used when creating a new doc)
  Map<String, dynamic> toCreateJson() => {
    'brand': brand,
    'model': model,
    'reference': reference,
    'movement': movement,
    'photoUrl': photoUrl,
    'purchaseDate': purchaseDate,
    'userId': userId,
    'createdAt': FieldValue.serverTimestamp(), // server time
  };
}
