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
}
