class Child {
  final String name;
  final String condition;
  final String image;

  Child({required this.name, required this.condition, required this.image});

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      name: json['name'] ?? '',
      condition: json['condition'] ?? '',
      image: json['image'] ?? '',
    );
  }
}
