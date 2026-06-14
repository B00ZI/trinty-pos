import 'package:Easify/models/order.dart';
import 'package:Easify/models/game_session.dart';
import 'package:Easify/models/app_user.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';

class OrderRepository {
  final ObjectBox _objectbox;
  late final Box<Ruci> _ruciBox;
  late final Box<GameSession> _gameSessionBox;

  OrderRepository(this._objectbox) {
    _ruciBox = _objectbox.store.box<Ruci>();
    _gameSessionBox = _objectbox.store.box<GameSession>();
  }

  Stream<Query<Ruci>> watchOrders() {
    return _ruciBox.query().watch();
  }

  Stream<Query<GameSession>> watchGameSessions() {
    return _gameSessionBox.query().watch();
  }

  List<Ruci> getOrdersByDateRange(DateTime start, DateTime end, int? userId) {
    final orderQueryBuilder = _ruciBox.query(Ruci_.date
        .between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch)
        .and(Ruci_.isDeleted.equals(false)));
    
    if (userId != null) {
      orderQueryBuilder.link(Ruci_.user, AppUser_.id.equals(userId));
    }
    
    final orderQuery = orderQueryBuilder.build();
    final periodOrders = orderQuery.find();
    orderQuery.close();
    
    return periodOrders;
  }

  List<GameSession> getGameSessionsByDateRange(DateTime start, DateTime end, int? userId) {
    Condition<GameSession> gameCondition = GameSession_.startTime
        .between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch)
        .and(GameSession_.status.equals(1)); // Completed only

    if (userId != null) {
      gameCondition = gameCondition.and(GameSession_.attributedUserId.equals(userId));
    }

    final gameQuery = _gameSessionBox.query(gameCondition).build();
    final periodGames = gameQuery.find();
    gameQuery.close();
    
    return periodGames;
  }
}
