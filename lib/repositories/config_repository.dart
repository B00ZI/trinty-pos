import 'package:Easify/models/store_config.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';

class ConfigRepository {
  final ObjectBox _objectbox;
  late final Box<StoreConfig> _storeConfigBox;

  ConfigRepository(this._objectbox) {
    _storeConfigBox = _objectbox.store.box<StoreConfig>();
  }

  Stream<Query<StoreConfig>> watchConfig() {
    return _storeConfigBox.query().watch();
  }

  StoreConfig getStoreConfig() {
    final configs = _storeConfigBox.getAll();
    return configs.isNotEmpty ? configs.first : StoreConfig();
  }
}
