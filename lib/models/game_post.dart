import 'package:objectbox/objectbox.dart';

@Entity()
class GamePost {
  @Id()
  int id;
  String label;        // e.g. "Post 1", "PS5 Left"
  bool isActive;       // true if a party is running

  GamePost({
    this.id = 0,
    required this.label,
    this.isActive = false,
  });
}
