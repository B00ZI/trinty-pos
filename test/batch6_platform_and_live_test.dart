import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart' as obx;

import 'package:Easify/models/app_user.dart';
import 'package:Easify/models/store_config.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:Easify/providers/auth_provider.dart';
import 'package:Easify/providers/dashboard_provider.dart';
import 'package:Easify/providers/settings_provider.dart';
import 'package:Easify/service/notification_service.dart';

/// Batch 6 — the platform truths (P52/P54) and the live settings (P57).
///
/// P54 — the pubspec is the app's identity card: version = the product
/// (3.0.0, build 30000 — renamed from 2.0.0+20002 when the app jumped to
/// version 3), real description, no dead packages.
///
/// P52 — the owner uses the app mainly on Android tablets, but the
/// notification service must never crash a non-Android build (Windows
/// throws UnimplementedError for every call).
///
/// P57 — a setting changed in Paramètres and a user added in Paramètres
/// show up everywhere at once, with no app restart.
void main() {
  final storeAvailable = Platform.environment['PATH']?.split(';').any(
          (d) => File('$d/objectbox.dll').existsSync()) ??
      false;
  final storeSkip = storeAvailable
      ? null
      : 'objectbox.dll not on PATH — build windows debug and add '
          'build\\windows\\x64\\runner\\Debug to PATH';

  group('P54 — the identity card says who the app is', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('version is the product: 3.0.0 with build 30000', () {
      expect(pubspec, contains('version: 3.0.0+30000'));
    });

    test('description is no longer the Flutter template', () {
      expect(pubspec, isNot(contains('A new Flutter project')));
      expect(pubspec, contains('Easify POS'));
    });

    test('the five dead packages are gone', () {
      for (final dead in [
        'cupertino_icons',
        'network_info_plus',
        'charset_converter',
        'mrx_charts',
        'audioplayers',
      ]) {
        expect(pubspec, isNot(contains(dead)),
            reason: '$dead should no longer be a dependency');
      }
    });
  });

  group('P52 — notifications cannot crash a non-Android app', () {
    test('init() and showHeadsUpNotification() complete quietly off-Android',
        () async {
      await expectLater(NotificationService.init(), completes);
      await expectLater(
          NotificationService.showHeadsUpNotification(
              title: 'Partie terminée', body: 'Poste 1 — le temps est écoulé'),
          completes);
    });
  });

  group('P57 — settings and users are live', () {
    late Directory tmpDir;
    late obx.Store store;
    late ObjectBox objectbox;
    late ProviderContainer container;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('easify_b6');
      store = obx.Store(getObjectBoxModel(), directory: tmpDir.path);
      objectbox = ObjectBox.attach(store);
      container = ProviderContainer(
          overrides: [objectBoxProvider.overrideWithValue(objectbox)]);
    });

    tearDown(() {
      container.dispose();
      store.close();
      tmpDir.deleteSync(recursive: true);
    });

    test('a user added after startup shows up in allUsersProvider', () async {
      final box = store.box<AppUser>();
      final (hash, salt) = AppUser.hashPin('1234');
      box.put(AppUser(name: 'Youssef', pin: hash, pinSalt: salt));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(container.read(allUsersProvider).map((u) => u.name),
          contains('Youssef'));

      box.put(AppUser(name: 'Fatima', pin: hash, pinSalt: salt));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(container.read(allUsersProvider).map((u) => u.name),
          contains('Fatima'),
          reason: 'a user added in Paramètres must appear without restart');
    }, skip: storeSkip);

    test('a store name changed after startup shows in storeConfigProvider',
        () async {
      // The app is running: the provider is already alive.
      container.read(storeConfigProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The owner changes the name, in Paramètres.
      final cfgBox = store.box<StoreConfig>();
      cfgBox.put(StoreConfig()..storeName = 'Café Zitouna');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(container.read(storeConfigProvider).storeName, 'Café Zitouna',
          reason: 'a changed setting must apply without an app restart');

      // And again later.
      final cfg = cfgBox.getAll().first;
      cfg.storeName = 'Café Noujoum';
      cfgBox.put(cfg);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(container.read(storeConfigProvider).storeName, 'Café Noujoum');
    }, skip: storeSkip);
  });
}
