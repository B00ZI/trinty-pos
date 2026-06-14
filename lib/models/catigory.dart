import 'package:objectbox/objectbox.dart';

@Entity()
class Catigory {
  @Id()
  int id;
  String name;
  String? imageUrl;

  int displayOrder = 0;

  Catigory({
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

  factory Catigory.fromJson(Map<String, dynamic> json) {
    return Catigory(
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      displayOrder: json['displayOrder'] as int? ?? 0,
    );
  }
}
