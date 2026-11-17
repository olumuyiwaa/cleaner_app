import '../../core/json.dart';

/// A workplace the signed-in user can act in.
class Affiliation {
  const Affiliation({
    required this.businessId,
    required this.businessName,
    required this.role,
  });

  final String businessId;
  final String businessName;
  final String role;

  factory Affiliation.fromJson(Map<String, dynamic> j) => Affiliation(
        businessId: str(j['businessId']) ?? '',
        businessName: str(j['businessName']) ?? '',
        role: str(j['role']) ?? '',
      );
}

/// The signed-in cleaner (GET /cleaners/me).
class CleanerProfile {
  const CleanerProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.businessName,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String businessName;

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    final s = (a + b).toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  CleanerProfile copyWith({String? phone, String? avatarUrl}) => CleanerProfile(
        id: id,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        businessName: businessName,
      );

  factory CleanerProfile.fromJson(Map<String, dynamic> j) {
    final user = mapOf(j['user']);
    final business = mapOf(j['business']);
    return CleanerProfile(
      id: str(j['id']) ?? '',
      firstName: str(user['firstName']) ?? '',
      lastName: str(user['lastName']) ?? '',
      email: str(user['email']) ?? '',
      phone: str(user['phone']),
      avatarUrl: str(user['avatarUrl']),
      businessName: str(business['name']) ?? '',
    );
  }
}

enum LoginKind { ok, selectBusiness, notCleaner }

class LoginResult {
  const LoginResult._(this.kind, [this.choices = const []]);

  const LoginResult.ok() : this._(LoginKind.ok);
  const LoginResult.notCleaner() : this._(LoginKind.notCleaner);
  const LoginResult.selectBusiness(List<Affiliation> choices)
      : this._(LoginKind.selectBusiness, choices);

  final LoginKind kind;
  final List<Affiliation> choices;
}
