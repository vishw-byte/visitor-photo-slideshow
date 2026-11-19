class VisitorModel {
  final String id;
  final String name;
  final String? email;
  final String sessionToken;
  final DateTime createdAt;

  VisitorModel({
    required this.id,
    required this.name,
    this.email,
    required this.sessionToken,
    required this.createdAt,
  });

  factory VisitorModel.fromJson(Map<String, dynamic> json) {
    return VisitorModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      sessionToken: json['session_token'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'session_token': sessionToken,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
