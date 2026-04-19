// lib/models/post_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  String status; // draft | saved | favorite
  String title;
  double price;
  String pricePeriod;
  String? address;
  double? latitude;
  double? longitude;
  String propertyType;
  String compoundType;
  int? numTenants;
  int bedrooms, bathrooms, toilets;
  bool waterAvailable, electricityAvailable, parkingAvailable;
  List<String> extraFeatures;
  List<String> imagePaths; // Changed from imageUrls to local paths
  String? description;
  String furnishing; // 'unfurnished' | 'semi_furnished' | 'fully_furnished'
  final DateTime createdAt;
  DateTime updatedAt;

  PostModel({
    required this.id,
    required this.userId,
    required this.status,
    required this.title,
    required this.price,
    required this.pricePeriod,
    this.address,
    this.latitude,
    this.longitude,
    required this.propertyType,
    required this.compoundType,
    this.numTenants,
    required this.bedrooms,
    required this.bathrooms,
    required this.toilets,
    required this.waterAvailable,
    required this.electricityAvailable,
    required this.parkingAvailable,
    required this.extraFeatures,
    required this.imagePaths, // Changed
    this.description,
    this.furnishing = 'unfurnished',
    required this.createdAt,
    required this.updatedAt,
  });

  factory PostModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      status: d['status'] ?? 'draft',
      title: d['title'] ?? '',
      price: (d['price'] as num?)?.toDouble() ?? 0,
      pricePeriod: d['pricePeriod'] ?? 'monthly',
      address: d['address'],
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      propertyType: d['propertyType'] ?? '',
      compoundType: d['compoundType'] ?? 'self_compound',
      numTenants: d['numTenants'],
      bedrooms: d['bedrooms'] ?? 0,
      bathrooms: d['bathrooms'] ?? 0,
      toilets: d['toilets'] ?? 0,
      waterAvailable: d['waterAvailable'] ?? false,
      electricityAvailable: d['electricityAvailable'] ?? false,
      parkingAvailable: d['parkingAvailable'] ?? false,
      extraFeatures: List<String>.from(d['extraFeatures'] ?? []),
      imagePaths: List<String>.from(d['imagePaths'] ?? []), // Changed
      description: d['description'],
      furnishing: d['furnishing'] ?? 'unfurnished',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'status': status,
    'title': title,
    'price': price,
    'pricePeriod': pricePeriod,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'propertyType': propertyType,
    'compoundType': compoundType,
    'numTenants': numTenants,
    'bedrooms': bedrooms,
    'bathrooms': bathrooms,
    'toilets': toilets,
    'waterAvailable': waterAvailable,
    'electricityAvailable': electricityAvailable,
    'parkingAvailable': parkingAvailable,
    'extraFeatures': extraFeatures,
    'imagePaths': imagePaths,
    'description': description,
    'furnishing': furnishing,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  /// JSON-safe map for Cloud Function calls (no FieldValue sentinels)
  Map<String, dynamic> toPropertyData() => {
    'title': title,
    'price': price,
    'pricePeriod': pricePeriod,
    'address': address,
    'propertyType': propertyType,
    'compoundType': compoundType,
    'numTenants': numTenants,
    'bedrooms': bedrooms,
    'bathrooms': bathrooms,
    'toilets': toilets,
    'waterAvailable': waterAvailable,
    'electricityAvailable': electricityAvailable,
    'parkingAvailable': parkingAvailable,
    'extraFeatures': extraFeatures,
    'imageCount': imagePaths.length,
    'description': description,
    'furnishing': furnishing,
    'latitude': latitude,
    'longitude': longitude,
  };
}

// lib/models/caption_version_model.dart
class CaptionVersionModel {
  final String id;
  final String postId;
  final String platform;
  String captionText;
  bool isSelected;
  final int generationNum;
  final DateTime createdAt;

  CaptionVersionModel({
    required this.id,
    required this.postId,
    required this.platform,
    required this.captionText,
    required this.isSelected,
    required this.generationNum,
    required this.createdAt,
  });

  factory CaptionVersionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CaptionVersionModel(
      id: doc.id,
      postId: d['postId'] ?? '',
      platform: d['platform'] ?? '',
      captionText: d['captionText'] ?? '',
      isSelected: d['isSelected'] ?? false,
      generationNum: d['generationNum'] ?? 1,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
// // lib/models/post_model.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// class PostModel {
//   final String id;
//   final String userId;
//   String status; // draft | saved | favorite
//   String title;
//   double price;
//   String pricePeriod;
//   String? address;
//   double? latitude;
//   double? longitude;
//   String propertyType;
//   String compoundType;
//   int? numTenants;
//   int bedrooms, bathrooms, toilets;
//   bool waterAvailable, electricityAvailable, parkingAvailable;
//   List<String> extraFeatures;
//   List<String> imageUrls;
//   final DateTime createdAt;
//   DateTime updatedAt;
//
//   PostModel({
//     required this.id,
//     required this.userId,
//     required this.status,
//     required this.title,
//     required this.price,
//     required this.pricePeriod,
//     this.address,
//     this.latitude,
//     this.longitude,
//     required this.propertyType,
//     required this.compoundType,
//     this.numTenants,
//     required this.bedrooms,
//     required this.bathrooms,
//     required this.toilets,
//     required this.waterAvailable,
//     required this.electricityAvailable,
//     required this.parkingAvailable,
//     required this.extraFeatures,
//     required this.imageUrls,
//     required this.createdAt,
//     required this.updatedAt,
//   });
//
//   factory PostModel.fromDoc(DocumentSnapshot doc) {
//     final d = doc.data() as Map<String, dynamic>;
//     return PostModel(
//       id:                   doc.id,
//       userId:               d['userId']        ?? '',
//       status:               d['status']        ?? 'draft',
//       title:                d['title']         ?? '',
//       price:                (d['price'] as num?)?.toDouble() ?? 0,
//       pricePeriod:          d['pricePeriod']   ?? 'monthly',
//       address:              d['address'],
//       latitude:             (d['latitude']  as num?)?.toDouble(),
//       longitude:            (d['longitude'] as num?)?.toDouble(),
//       propertyType:         d['propertyType']  ?? '',
//       compoundType:         d['compoundType']  ?? 'self_compound',
//       numTenants:           d['numTenants'],
//       bedrooms:             d['bedrooms']      ?? 0,
//       bathrooms:            d['bathrooms']     ?? 0,
//       toilets:              d['toilets']       ?? 0,
//       waterAvailable:       d['waterAvailable']       ?? false,
//       electricityAvailable: d['electricityAvailable'] ?? false,
//       parkingAvailable:     d['parkingAvailable']     ?? false,
//       extraFeatures:        List<String>.from(d['extraFeatures'] ?? []),
//       imageUrls:            List<String>.from(d['imageUrls'] ?? []),
//       createdAt:            (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//       updatedAt:            (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//     );
//   }
//
//   Map<String, dynamic> toMap() => {
//     'userId':               userId,
//     'status':               status,
//     'title':                title,
//     'price':                price,
//     'pricePeriod':          pricePeriod,
//     'address':              address,
//     'latitude':             latitude,
//     'longitude':            longitude,
//     'propertyType':         propertyType,
//     'compoundType':         compoundType,
//     'numTenants':           numTenants,
//     'bedrooms':             bedrooms,
//     'bathrooms':            bathrooms,
//     'toilets':              toilets,
//     'waterAvailable':       waterAvailable,
//     'electricityAvailable': electricityAvailable,
//     'parkingAvailable':     parkingAvailable,
//     'extraFeatures':        extraFeatures,
//     'imageUrls':            imageUrls,
//     'createdAt':            FieldValue.serverTimestamp(),
//     'updatedAt':            FieldValue.serverTimestamp(),
//   };
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // lib/models/caption_version_model.dart
// class CaptionVersionModel {
//   final String id;
//   final String postId;
//   final String platform;
//   String captionText;
//   bool isSelected;
//   final int generationNum;
//   final DateTime createdAt;
//
//   CaptionVersionModel({
//     required this.id,
//     required this.postId,
//     required this.platform,
//     required this.captionText,
//     required this.isSelected,
//     required this.generationNum,
//     required this.createdAt,
//   });
//
//   factory CaptionVersionModel.fromDoc(DocumentSnapshot doc) {
//     final d = doc.data() as Map<String, dynamic>;
//     return CaptionVersionModel(
//       id:            doc.id,
//       postId:        d['postId']        ?? '',
//       platform:      d['platform']      ?? '',
//       captionText:   d['captionText']   ?? '',
//       isSelected:    d['isSelected']    ?? false,
//       generationNum: d['generationNum'] ?? 1,
//       createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//     );
//   }
// }
