import 'package:objectbox/objectbox.dart';
import 'game_post.dart';
import 'party_tier.dart';

@Entity()
class GameSession {
  @Id()
  int id;

  int postId;
  int tierId;
  String postLabel;        // snapshot
  int partyNumber;
  String tierLabel;        // snapshot
  DateTime startTime;
  DateTime endTime;
  DateTime? actualEndTime; // set if ended early
  int status;              // 0=active, 1=completed, 2=cancelled
  double price;            // snapshot of tier price
  int? attributedUserId;

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
    required this.endTime,
    this.actualEndTime,
    this.status = 0,
    required this.price,
    this.attributedUserId,
  });

  // Helpers
  bool get isActive => status == 0;
  bool get isCompleted => status == 1;
  bool get isCancelled => status == 2;
  bool get isOpenSession => endTime.difference(startTime).inMinutes == 0;
}
