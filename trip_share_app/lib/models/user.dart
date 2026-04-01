class AppUser {
  final String uid;
  final String email;
  final String name;
  final String photoUrl;
  final String phoneNumber; // Format: +XX XXXXXXXXX
  final String countryCode; // Format: +XX
  final String role; // 'passenger' or 'admin' or 'driver'
  final DateTime createdAt;
  final DateTime lastLogin;
  final List<String> joinedTourIds; // Tour IDs user has booked/joined
  final List<String> startedTourIds; // Tour IDs user has started/created

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.phoneNumber,
    required this.countryCode,
    required this.role,
    required this.createdAt,
    required this.lastLogin,
    this.joinedTourIds = const [],
    this.startedTourIds = const [],
  });

  /// Empty user instance
  factory AppUser.empty() => AppUser(
    uid: '',
    email: '',
    name: '',
    photoUrl: '',
    phoneNumber: '',
    countryCode: '',
    role: 'passenger',
    createdAt: DateTime.now(),
    lastLogin: DateTime.now(),
  );

  /// Convert to Firestore document data
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'phoneNumber': phoneNumber,
      'countryCode': countryCode,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'joinedTourIds': joinedTourIds,
      'startedTourIds': startedTourIds,
    };
  }

  /// Create from Firestore document data
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      countryCode: map['countryCode'] ?? '',
      role: map['role'] ?? 'passenger',
      createdAt: map['createdAt'] is String
          ? DateTime.parse(map['createdAt'])
          : (map['createdAt']?.toDate() ?? DateTime.now()),
      lastLogin: map['lastLogin'] is String
          ? DateTime.parse(map['lastLogin'])
          : (map['lastLogin']?.toDate() ?? DateTime.now()),
      joinedTourIds: List<String>.from(map['joinedTourIds'] ?? []),
      startedTourIds: List<String>.from(map['startedTourIds'] ?? []),
    );
  }

  /// Copy with modifications
  AppUser copyWith({
    String? uid,
    String? email,
    String? name,
    String? photoUrl,
    String? phoneNumber,
    String? countryCode,
    String? role,
    DateTime? createdAt,
    DateTime? lastLogin,
    List<String>? joinedTourIds,
    List<String>? startedTourIds,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      countryCode: countryCode ?? this.countryCode,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      joinedTourIds: joinedTourIds ?? this.joinedTourIds,
      startedTourIds: startedTourIds ?? this.startedTourIds,
    );
  }
}
