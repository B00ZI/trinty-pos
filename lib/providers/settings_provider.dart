import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/models/store_config.dart';
import 'package:Easify/models/printer_config.dart';
import 'dashboard_provider.dart';

// ConfigRepository is already provided by dashboard_provider.dart via configRepositoryProvider

// Store config stream – reactive updates from ObjectBox
final storeConfigStreamProvider = StreamProvider<StoreConfig>((ref) {
  final repo = ref.watch(configRepositoryProvider);
  return repo
      .watchStoreConfigList()
      .map((configs) => configs.isNotEmpty ? configs.first : StoreConfig());
});

// Convenience getter for the current store config value
final storeConfigProvider = Provider<StoreConfig>((ref) {
  final repo = ref.watch(configRepositoryProvider);
  return repo.getStoreConfig();
});

// Printer config stream
final printerConfigStreamProvider = StreamProvider<List<PrinterConfig>>((ref) {
  final repo = ref.watch(configRepositoryProvider);
  // Watch all printer configs reactively
  return repo.watchPrinterConfig().map((q) => q.find());
});

// Convenience getter for the first (primary) printer config
final printerConfigProvider = Provider<PrinterConfig?>((ref) {
  final repo = ref.watch(configRepositoryProvider);
  return repo.getPrinterConfig();
});

// Surge pricing helper – reads store config and checks if a product is surged
final surgePriceEnabledProvider = Provider<bool>((ref) {
  final config = ref.watch(storeConfigProvider);
  return config.isSurgePriceEnabled;
});
