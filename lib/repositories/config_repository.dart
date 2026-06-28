import 'package:Easify/models/store_config.dart';
import 'package:Easify/models/printer_config.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:objectbox/objectbox.dart';

class ConfigRepository {
  final ObjectBox _objectbox;
  late final Box<StoreConfig> _storeConfigBox;
  late final Box<PrinterConfig> _printerConfigBox;

  ConfigRepository(this._objectbox) {
    _storeConfigBox = _objectbox.store.box<StoreConfig>();
    _printerConfigBox = _objectbox.store.box<PrinterConfig>();
  }

  // Store Config
  Stream<Query<StoreConfig>> watchStoreConfig() {
    return _storeConfigBox.query().watch();
  }

  StoreConfig getStoreConfig() {
    final configs = _storeConfigBox.getAll();
    return configs.isNotEmpty ? configs.first : StoreConfig();
  }

  void putStoreConfig(StoreConfig config) {
    _storeConfigBox.put(config);
  }

  Stream<List<StoreConfig>> watchStoreConfigList() {
    return _storeConfigBox.query().watch(triggerImmediately: true).map((q) => q.find());
  }

  // Printer Config
  Stream<Query<PrinterConfig>> watchPrinterConfig() {
    return _printerConfigBox.query().watch(triggerImmediately: true);
  }

  PrinterConfig? getPrinterConfig() {
    final configs = _printerConfigBox.getAll();
    return configs.isNotEmpty ? configs.first : null;
  }

  void putPrinterConfig(PrinterConfig config) {
    _printerConfigBox.put(config);
  }

  List<PrinterConfig> getAllPrinterConfigs() {
    return _printerConfigBox.getAll();
  }

  void removePrinterConfig(int id) {
    _printerConfigBox.remove(id);
  }

  // Alias used by dashboard change-stream invalidation
  Stream<Query<StoreConfig>> watchConfig() => watchStoreConfig();
}
