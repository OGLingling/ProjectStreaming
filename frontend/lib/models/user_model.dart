class User {
  final String id;
  final String email;
  final String name;
  final bool isVerified;
  final DateTime? createdAt;
  final String? profilePic;
  final String? plan;

  User({
    required this.id, // Ahora es requerido porque viene de Firebase
    required this.email,

    required this.name,
    this.isVerified = false, // Valor por defecto
    this.createdAt,
    this.profilePic,
    this.plan,
  });

  // Constructor para recibir datos del Backend
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"].toString(), // Aseguramos que sea String
    email: json["email"],
    name: json["name"],
    isVerified: json["isVerified"] ?? false,
    createdAt: json["createdAt"] != null
        ? DateTime.parse(json["createdAt"])
        : null,
    profilePic: json["profilePic"],
    plan: json["plan"],
  );

  // Para enviar datos al Backend
  Map<String, dynamic> toJson() => {
    "id": id,
    "email": email,
    "name": name,
    "isVerified": isVerified,
    "profilePic": profilePic,
    "createdAt": createdAt?.toIso8601String(),
    "plan": plan,
  };
}
