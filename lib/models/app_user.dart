import 'package:objectbox/objectbox.dart';

@Entity()
class AppUser {
  @Id()
  int id;

  String name;

  AppUser({
    this.id = 0,
    required this.name,
  });
}
