import 'package:objectbox/objectbox.dart';

@Entity()
class StoreConfig {
  @Id()
  int id;

  String? storeName;
  String? storePhone;
  String? storeLogoPath;

  int dayStartHour;
  int dayStartMinute;
  int dayEndHour;
  int dayEndMinute;

  StoreConfig({
    this.id = 0,
    this.storeName,
    this.storePhone,
    this.storeLogoPath,
    this.dayStartHour = 0,
    this.dayStartMinute = 0,
    this.dayEndHour = 23,
    this.dayEndMinute = 59,
  });
}
