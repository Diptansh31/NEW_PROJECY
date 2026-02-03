class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.username,
    required this.gender,
    required this.bio,
    required this.interests,
    this.profileImageBytes,
  });

  final String uid;
  final String email;
  final String username;
  final Gender gender;
  final String bio;
  final List<String> interests;

  /// Raw image bytes (web-friendly). Persist this later (e.g., Firebase Storage).
  final List<int>? profileImageBytes;
}

enum Gender {
  male,
  female,
  nonBinary,
  preferNotToSay,
}

extension GenderLabel on Gender {
  String get label {
    return switch (this) {
      Gender.male => 'Male',
      Gender.female => 'Female',
      Gender.nonBinary => 'Non-binary',
      Gender.preferNotToSay => 'Prefer not to say',
    };
  }
}
