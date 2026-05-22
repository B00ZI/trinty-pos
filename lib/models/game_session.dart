import 'package:objectbox/objectbox.dart';
import 'game_post.dart';
import 'party_tier.dart';

@Entity()
class GameSession {
  @Id()
  int id;

  int postId;
  int tierId;
  String postLabel; // snapshot
  int partyNumber;
  String tierLabel; // snapshot
  DateTime startTime;
  DateTime? endTime; // null if session is active
  int status; // 0=active, 1=completed, 2=cancelled
  double ratePerHour; // snapshot of tier rate
  int? attributedUserId;
  int? relatedOrderId;
  bool isLimitedDuration;
  int limitedDurationMinutes;

  // Relations
  final post = ToOne<GamePost>();
  final tier = ToOne<PartyTier>();

  GameSession({
    this.id = 0,
    this.postId = 0,
    this.tierId = 0,
    required this.postLabel,
    required this.partyNumber,
    required this.tierLabel,
    required this.startTime,
    this.endTime,
    this.status = 0,
    required this.ratePerHour,
    this.attributedUserId,
    this.relatedOrderId,
    this.isLimitedDuration = false,
    this.limitedDurationMinutes = 0,
  });

  // Helpers
  bool get isActive => status == 0;
  bool get isCompleted => status == 1;
  bool get isCancelled => status == 2;

  double get currentCalculatedPrice {
    if (isLimitedDuration) {
      return (limitedDurationMinutes / 60.0) * ratePerHour;
    }
    final end = endTime ?? DateTime.now();
    final duration = end.difference(startTime);
    final seconds = duration.inSeconds;
    // Price = (seconds / 3600) * ratePerHour
    return (seconds / 3600.0) * ratePerHour;
  }
}
