class Parent {
  final String name;
  final String phone;
  final String address;
  final String email;
  final String profilePicture;

  Parent({
    required this.name,
    required this.phone,
    required this.address,
    required this.email,
    required this.profilePicture,
  });

  factory Parent.fromJson(Map<String, dynamic> json) {
    return Parent(
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      email: json['email'] ?? '',
      profilePicture: json['profile_picture'] ?? '',
    );
  }
}
