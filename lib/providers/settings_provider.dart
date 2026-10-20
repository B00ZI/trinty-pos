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

// Convenience getter for the current store config value.
// P57: live — it used to read the config ONCE and cache it forever, so a
// setting changed in Paramètres kept the old value until an app restart
// (tax, day mode, surge pricing…). Now it follows the stream below.
final storeConfigProvider = Provider<StoreConfig>((ref) {
  return ref.watch(storeConfigStreamProvider).value ?? StoreConfig();
});

// Printer config stream
final printerConfigStreamProvider = StreamProvider<List<PrinterConfig>>((ref) {
  final repo = ref.watch(configRepositoryProvider);
  // Watch all printer configs reactively
  return repo.watchPrinterConfig().map((q) => q.find());
});

// Convenience getter for the first (primary) printer config
// P57: live, same reasoning as storeConfigProvider.
final printerConfigProvider = Provider<PrinterConfig?>((ref) {
  return ref.watch(printerConfigStreamProvider).valueOrNull?.firstOrNull;
});

// Surge pricing helper – reads store config and checks if a product is surged
final surgePriceEnabledProvider = Provider<bool>((ref) {
  final config = ref.watch(storeConfigProvider);
  return config.isSurgePriceEnabled;
});
