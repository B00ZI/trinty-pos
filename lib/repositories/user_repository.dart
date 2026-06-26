import 'package:Easify/models/app_user.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:objectbox/objectbox.dart';

class UserRepository {
  final ObjectBox _objectbox;
  late final Box<AppUser> _userBox;

  UserRepository(this._objectbox) {
    _userBox = _objectbox.store.box<AppUser>();
  }

  List<AppUser> getAll() {
    return _userBox.getAll();
  }

  AppUser? getById(int id) {
    return _userBox.get(id);
  }

  AppUser? getAdmin() {
    final query = _userBox.query(AppUser_.isAdmin.equals(true)).build();
    final result = query.findFirst();
    query.close();
    return result;
  }

  bool hasAdmin() {
    return _userBox.getAll().any((u) => u.isAdmin);
  }

  void put(AppUser user) {
    _userBox.put(user);
  }

  void remove(int id) {
    _userBox.remove(id);
  }

  AppUser? verifyPin(String rawPin) {
    final users = _userBox.getAll();
    for (final user in users) {
      if (user.verifyPin(rawPin)) {
        // Transparently upgrade legacy (unsalted) PINs to salted hashes
        if (user.needsPinUpgrade) {
          final (hash, salt) = AppUser.hashPin(rawPin);
          user.pin = hash;
          user.pinSalt = salt;
          _userBox.put(user);
        }
        return user;
      }
    }
    return null;
  }

  Stream<List<AppUser>> watchAll() {
    return _userBox.query().watch().map((q) => q.find());
  }
}
