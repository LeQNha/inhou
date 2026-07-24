class Owner {
  final String id; // = Firebase Auth uid khi migrate
  final String email;
  final String displayName;

  const Owner({
    required this.id,
    required this.email,
    required this.displayName,
  });

  factory Owner.fromMap(Map<String, dynamic> map) => Owner(
        id: map['id'] as String,
        email: map['email'] as String,
        displayName: map['display_name'] as String,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'display_name': displayName,
      };
}
