import 'package:objectbox/objectbox.dart';

@Entity()
class Catigory {
  @Id()
  int id;
  String name;
  String? imageUrl;

  Catigory({
    this.id = 0,
    required this.name,
    this.imageUrl,
  });
}
