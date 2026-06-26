import 'package:Easify/models/game_session.dart';
import 'package:Easify/models/game_post.dart';
import 'package:Easify/models/party_tier.dart';
import 'package:Easify/models/party_counter.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:objectbox/objectbox.dart';

class GameSessionRepository {
  final ObjectBox _objectbox;
  late final Box<GameSession> _sessionBox;
  late final Box<GamePost> _postBox;
  late final Box<PartyTier> _tierBox;
  late final Box<PartyCounter> _counterBox;

  GameSessionRepository(this._objectbox) {
    _sessionBox = _objectbox.store.box<GameSession>();
    _postBox = _objectbox.store.box<GamePost>();
    _tierBox = _objectbox.store.box<PartyTier>();
    _counterBox = _objectbox.store.box<PartyCounter>();
  }

  // Game Sessions
  List<GameSession> getAllSessions() {
    return _sessionBox.getAll();
  }

  Stream<List<GameSession>> watchSessions() {
    return _sessionBox.query().watch().map((q) => q.find());
  }

  List<GameSession> getActiveSessions() {
    final query = _sessionBox
        .query(GameSession_.status.equals(0))
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  List<GameSession> getCompletedSessions() {
    final query = _sessionBox
        .query(GameSession_.status.equals(1))
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  void putSession(GameSession session) {
    _sessionBox.put(session);
  }

  void removeSession(int id) {
    _sessionBox.remove(id);
  }

  GameSession? getSessionById(int id) {
    return _sessionBox.get(id);
  }

  // Game Posts
  List<GamePost> getAllPosts() {
    return _postBox.getAll();
  }

  List<GamePost> getActivePosts() {
    final query = _postBox
        .query(GamePost_.isActive.equals(true))
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  void putPost(GamePost post) {
    _postBox.put(post);
  }

  void removePost(int id) {
    _postBox.remove(id);
  }

  Stream<List<GamePost>> watchPosts() {
    return _postBox.query().watch().map((q) => q.find());
  }

  // Party Tiers
  List<PartyTier> getAllTiers() {
    return _tierBox.getAll();
  }

  void putTier(PartyTier tier) {
    _tierBox.put(tier);
  }

  void removeTier(int id) {
    _tierBox.remove(id);
  }

  Stream<List<PartyTier>> watchTiers() {
    return _tierBox.query().watch().map((q) => q.find());
  }

  // Party Counter
  int getCurrentPartyNumber() {
    final counters = _counterBox.getAll();
    if (counters.isEmpty) {
      final counter = PartyCounter(id: 1, value: 1);
      _counterBox.put(counter);
      return 1;
    }
    return counters.first.value;
  }

  int incrementPartyNumber() {
    final current = getCurrentPartyNumber();
    final next = current + 1;
    _counterBox.put(PartyCounter(id: 1, value: next));
    return next;
  }
}
