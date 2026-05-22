import 'package:objectbox/objectbox.dart';

@Entity()
class StoreConfig {
  @Id()
  int id;

  String? storeName;
  String? storePhone;
  String? storeLogoPath;
  String? wifiPassword;

  int dayStartHour;
  int dayStartMinute;
  int dayEndHour;
  int dayEndMinute;

  bool isSurgePriceEnabled;
  double surgePriceAmount;
  List<int> surgeProductIds;

  StoreConfig({
    this.id = 0,
    this.storeName,
    this.storePhone,
    this.storeLogoPath,
    this.wifiPassword,
    this.dayStartHour = 0,
    this.dayStartMinute = 0,
    this.dayEndHour = 23,
    this.dayEndMinute = 59,
    this.isSurgePriceEnabled = false,
    this.surgePriceAmount = 0.0,
    this.surgeProductIds = const [],
  });
}
