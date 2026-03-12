import 'package:objectbox/objectbox.dart';

@Entity()
class PrinterConfig {
  int id;
  String ipAddress;
  int port;
  bool singleTicketMode;
  bool enableChangeWindow;

  PrinterConfig({
    this.id = 0,
    required this.ipAddress,
    required this.port,
    this.singleTicketMode = false,
    this.enableChangeWindow = true,
  });
}
