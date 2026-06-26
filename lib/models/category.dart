import 'package:objectbox/objectbox.dart';

@Entity(uid: 2621355858066362497)
class Category {
  @Id()
  int id;
  String name;
  String? imageUrl;

  int displayOrder = 0;

  Category({
    this.id = 0,
    required this.name,
    this.imageUrl,
    this.displayOrder = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'displayOrder': displayOrder,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }
}
