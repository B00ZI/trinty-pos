import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/models/app_user.dart';
import 'package:Easify/repositories/user_repository.dart';
import 'package:Easify/service/auth_service.dart';
import 'dashboard_provider.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final ob = ref.watch(objectBoxProvider);
  return UserRepository(ob);
});

// Current authenticated user
final currentUserProvider = StateProvider<AppUser?>((ref) => null);

// Auth mode
final authModeProvider = FutureProvider<AuthMode>((ref) async {
  return await AuthService.getAuthMode();
});

// P57: the users list as a live stream (fires on any add/change/delete).
final _usersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchAll();
});

// All users — P57: live. It used to read ONCE at startup, so a user added
// in Paramètres did not appear on the Dashboard until an app restart.
final allUsersProvider = Provider<List<AppUser>>((ref) {
  // First paint shows what is already in the box; the stream keeps it fresh.
  final fromStream = ref.watch(_usersStreamProvider).value;
  if (fromStream != null) return fromStream;
  return ref.watch(userRepositoryProvider).getAll();
});

// Check if current user is admin
final isAdminProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser?.isAdmin ?? false;
});
