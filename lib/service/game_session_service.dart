import '../models/game_post.dart';
import '../models/party_tier.dart';
import '../models/game_session.dart';
import '../models/party_counter.dart';
import '../objectbox.dart';
import 'package:objectbox/objectbox.dart';
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

  static Future<GameSession> startSession({
    required GamePost post,
    required PartyTier tier,
    required int? userId,
    required ObjectBox objectbox,
  }) async {
    final partyNumber = await getNextPartyNumber(objectbox);
    final startTime = DateTime.now();
    final endTime = tier.durationMinutes > 0
        ? startTime.add(Duration(minutes: tier.durationMinutes))
        : startTime; // 0 duration means open session

    final session = GameSession(
      postLabel: post.label,
      partyNumber: partyNumber,
      tierLabel: tier.label,
      startTime: startTime,
      endTime: endTime,
      price: tier.price,
      attributedUserId: userId,
    );

    session.post.target = post;
    session.tier.target = tier;

    // Update post status
    post.isActive = true;
    objectbox.gamePostBox.put(post);

    // Save session
    objectbox.gameSessionBox.put(session);
    
    return session;
  }

  static void endSession(GameSession session, ObjectBox objectbox) {
    session.status = 1; // Completed
    session.actualEndTime = DateTime.now();
    objectbox.gameSessionBox.put(session);

    final post = session.post.target;
    if (post != null) {
      post.isActive = false;
      objectbox.gamePostBox.put(post);
    }
  }

  static void cancelSession(GameSession session, ObjectBox objectbox) {
    session.status = 2; // Cancelled
    session.actualEndTime = DateTime.now();
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
}
