import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Easify/models/game_session.dart';
import 'package:Easify/models/game_post.dart';
import 'package:Easify/models/party_tier.dart';
import 'package:Easify/repositories/game_session_repository.dart';
import 'dashboard_provider.dart';

final gameSessionRepositoryProvider = Provider<GameSessionRepository>((ref) {
  final ob = ref.watch(objectBoxProvider);
  return GameSessionRepository(ob);
});

// Active game sessions
final activeSessionsProvider = StreamProvider<List<GameSession>>((ref) {
  final repo = ref.watch(gameSessionRepositoryProvider);
  return repo.watchSessions().map((sessions) => 
    sessions.where((s) => s.isActive).toList()
  );
});

// All game sessions
final allSessionsProvider = StreamProvider<List<GameSession>>((ref) {
  final repo = ref.watch(gameSessionRepositoryProvider);
  return repo.watchSessions();
});

// Game posts
final gamePostsProvider = StreamProvider<List<GamePost>>((ref) {
  final repo = ref.watch(gameSessionRepositoryProvider);
  return repo.watchPosts();
});

// Active game posts
final activePostsProvider = Provider<AsyncValue<List<GamePost>>>((ref) {
  final postsAsync = ref.watch(gamePostsProvider);
  return postsAsync.whenData((posts) => 
    posts.where((p) => p.isActive).toList()
  );
});

// Party tiers
final partyTiersProvider = StreamProvider<List<PartyTier>>((ref) {
  final repo = ref.watch(gameSessionRepositoryProvider);
  return repo.watchTiers();
});
