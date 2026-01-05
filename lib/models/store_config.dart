import 'package:objectbox/objectbox.dart';

@Entity()
class StoreConfig {
  @Id()
  int id;

  String? storeName;
  String? storeLogoPath;

  StoreConfig({
    this.id = 0,
    this.storeName,
    this.storeLogoPath,
  });
}
