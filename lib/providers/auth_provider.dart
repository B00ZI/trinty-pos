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

// All users
final allUsersProvider = Provider<List<AppUser>>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  return repo.getAll();
});

// Check if current user is admin
final isAdminProvider = Provider<bool>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  return currentUser?.isAdmin ?? false;
});
