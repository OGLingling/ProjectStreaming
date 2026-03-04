class User {
  final int? id;
  final String email;
  final String password;
  final String name; // Ahora es obligatorio según tu Prisma
  final DateTime? createdAt;
  final String? profilePic;

  User({
    this.id,
    required this.email,
    required this.password,
    required this.name,
    this.createdAt,
    this.profilePic,
  });

  // Constructor para recibir datos del Backend
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json["id"],
    email: json["email"],
    password: json["password"],
    name: json["name"],
    // Convertimos el String de la base de datos a un objeto DateTime de Dart
    createdAt: json["createdAt"] != null
        ? DateTime.parse(json["createdAt"])
        : null,
    profilePic: json["profilePic"],
  );

  // Para enviar datos al Backend (por ejemplo en el Registro)
  Map<String, dynamic> toJson() => {
    "id": id,
    "email": email,
    "password": password,
    "name": name,
    "profilePic": profilePic,
    "createdAt": createdAt?.toIso8601String(),
  };
}
