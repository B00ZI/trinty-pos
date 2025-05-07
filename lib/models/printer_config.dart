import 'package:objectbox/objectbox.dart';

@Entity()
class PrinterConfig {
  int id;
  String ipAddress;
  int port;

  PrinterConfig({this.id = 0, required this.ipAddress, required this.port});
}