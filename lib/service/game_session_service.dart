import '../models/game_post.dart';
import '../models/party_tier.dart';
import '../models/game_session.dart';
import '../models/party_counter.dart';
import '../objectbox.dart';
// import 'package:objectbox/objectbox.dart';
import '../objectbox.g.dart'; // This will be generated

class GameSessionService {
  static Future<int> getNextPartyNumber(ObjectBox objectbox) async {
    final counterBox = objectbox.partyCounterBox;
    PartyCounter counter;
    if (counterBox.isEmpty()) {
      counter = PartyCounter(id: 1, value: 1);
    } else {
      counter = counterBox.get(1)!;
    }
    final number = counter.value;
    counter.value += 1;
    counterBox.put(counter);
    return number;
  }

  /// Builds a session IN MEMORY and performs **no** session write.
  ///
  /// P24: the paid-start flow needs the session object to be written inside
  /// the SAME transaction as its order (one sealed save: order + counter +
  /// session + `relatedOrderId` link) — otherwise a crash between the two
  /// writes leaves the session unlinked and the same sale is counted twice
  /// (order revenue + "unlinked" session revenue). The only write here is
  /// the party-number counter bump, whose worst case is a skipped number.
  static Future<GameSession> prepareSession({
    required GamePost post,
    required PartyTier tier,
    required int? userId,
    required ObjectBox objectbox,
    int? durationMinutes,
  }) async {
    final partyNumber = await getNextPartyNumber(objectbox);
    final session = GameSession(
      postLabel: post.label,
      partyNumber: partyNumber,
      tierLabel: tier.label,
      startTime: DateTime.now(),
      ratePerHour: tier.ratePerHour,
      attributedUserId: userId,
      isLimitedDuration: durationMinutes != null,
      limitedDurationMinutes: durationMinutes ?? 0,
    );

    session.post.target = post;
    session.tier.target = tier;
    return session;
  }

  static Future<GameSession> startSession({
    required GamePost post,
    required PartyTier tier,
    required int? userId,
    required ObjectBox objectbox,
    int? durationMinutes,
  }) async {
    final session = await prepareSession(
      post: post,
      tier: tier,
      userId: userId,
      objectbox: objectbox,
      durationMinutes: durationMinutes,
    );

    // Update post status
    post.isActive = true;
    objectbox.gamePostBox.put(post);

    // Save session
    objectbox.gameSessionBox.put(session);
    
    return session;
  }

  /// Promotes the next queued session on [post] to "running" (or frees the
  /// post). Split out of [endSession] (P24) so a caller can commit its own
  /// money-critical transaction first and run this afterwards.
  static void promoteNextQueued(GamePost post, ObjectBox objectbox) {
    // Check if there's a queued session for this post
    final queuedSession = getNextQueuedSessionForPost(post.id, objectbox);
    if (queuedSession != null) {
      // Start the queued session
      queuedSession.status = 0;
      queuedSession.startTime = DateTime.now();
      queuedSession.endTime = null;
      objectbox.gameSessionBox.put(queuedSession);

      post.isActive = true;
    } else {
      post.isActive = false;
    }
    objectbox.gamePostBox.put(post);
  }

  static void endSession(GameSession session, ObjectBox objectbox, {int? relatedOrderId}) {
    session.status = 1; // Completed
    session.endTime = DateTime.now();
    if (relatedOrderId != null) {
      session.relatedOrderId = relatedOrderId;
    }
    objectbox.gameSessionBox.put(session);

    final post = session.post.target;
    if (post != null) {
      promoteNextQueued(post, objectbox);
    }
  }

  static void cancelSession(GameSession session, ObjectBox objectbox) {
    session.status = 2; // Cancelled
    session.endTime = DateTime.now();
    objectbox.gameSessionBox.put(session);

    final post = session.post.target;
    if (post != null) {
      post.isActive = false;
      objectbox.gamePostBox.put(post);
    }
  }

  static GameSession? getActiveSessionForPost(int postId, ObjectBox objectbox) {
    final query = objectbox.gameSessionBox
        .query(GameSession_.post.equals(postId).and(GameSession_.status.equals(0)))
        .build();
    final session = query.findFirst();
    query.close();
    return session;
  }

  static GameSession? getNextQueuedSessionForPost(int postId, ObjectBox objectbox) {
    final query = objectbox.gameSessionBox
        .query(GameSession_.post.equals(postId).and(GameSession_.status.equals(3)))
        .order(GameSession_.id)
        .build();
    final session = query.findFirst();
    query.close();
    return session;
  }

  static Future<GameSession> queueSession({
    required GamePost post,
    required PartyTier tier,
    required int? userId,
    required ObjectBox objectbox,
  }) async {
    final partyNumber = await getNextPartyNumber(objectbox);
    
    final session = GameSession(
      postLabel: post.label,
      partyNumber: partyNumber,
      tierLabel: tier.label,
      startTime: DateTime.now(), // placeholder
      ratePerHour: tier.ratePerHour,
      attributedUserId: userId,
      status: 3, // Queued
    );

    session.post.target = post;
    session.tier.target = tier;

    objectbox.gameSessionBox.put(session);
    return session;
  }
}
