import 'package:Easify/models/order.dart' as order_model;
import 'package:Easify/models/order_item.dart';
import 'package:Easify/models/order_counter.dart';
import 'package:Easify/models/game_session.dart';
import 'package:Easify/models/app_user.dart';
import 'package:Easify/objectbox.dart';
import 'package:Easify/objectbox.g.dart';
import 'package:objectbox/objectbox.dart';

class OrderRepository {
  final ObjectBox _objectbox;
  late final Box<order_model.Order> _orderBox;
  late final Box<OrderItem> _orderItemBox;
  late final Box<OrderCounter> _orderCounterBox;
  late final Box<GameSession> _gameSessionBox;

  OrderRepository(this._objectbox) {
    _orderBox = _objectbox.store.box<order_model.Order>();
    _orderItemBox = _objectbox.store.box<OrderItem>();
    _orderCounterBox = _objectbox.store.box<OrderCounter>();
    _gameSessionBox = _objectbox.store.box<GameSession>();
  }

  // Orders
  Stream<Query<order_model.Order>> watchOrders() {
    return _orderBox.query().watch();
  }

  List<order_model.Order> getAllOrders() {
    return _orderBox.getAll();
  }

  order_model.Order? getOrderById(int id) {
    return _orderBox.get(id);
  }

  void putOrder(order_model.Order order) {
    try {
      _orderBox.put(order);
    } catch (e) {
      throw Exception('Failed to save order: $e');
    }
  }

  void removeOrder(int id) {
    try {
      _orderBox.remove(id);
    } catch (e) {
      throw Exception('Failed to delete order: $e');
    }
  }

  List<order_model.Order> getOrdersByDateRange(
      DateTime start, DateTime end, int? userId) {
    final orderQueryBuilder = _orderBox.query(Order_.date
        .between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch)
        .and(Order_.isDeleted.equals(false)));

    if (userId != null) {
      orderQueryBuilder.link(Order_.user, AppUser_.id.equals(userId));
    }

    final orderQuery = orderQueryBuilder.build();
    final periodOrders = orderQuery.find();
    orderQuery.close();

    return periodOrders;
  }

  Stream<List<order_model.Order>> watchOrdersByDateRange(
      DateTime start, DateTime end) {
    return _orderBox
        .query(Order_.date
            .between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch))
        .watch(triggerImmediately: true)
        .map((q) => q.find());
  }

  // Order Counter
  int getNextOrderNumber() {
    final counters = _orderCounterBox.getAll();
    if (counters.isEmpty) {
      final counter = OrderCounter(id: 1, value: 1);
      _orderCounterBox.put(counter);
      return 1;
    }
    return counters.first.value;
  }

  int incrementOrderNumber() {
    final current = getNextOrderNumber();
    final next = current + 1;
    _orderCounterBox.put(OrderCounter(id: 1, value: next));
    return current;
  }

  void resetOrderCounter() {
    _orderCounterBox.removeAll();
    _orderCounterBox.put(OrderCounter(id: 1, value: 1));
  }

  // Order Items
  void putOrderItem(OrderItem item) {
    _orderItemBox.put(item);
  }

  void removeOrderItem(int id) {
    _orderItemBox.remove(id);
  }

  void removeAllOrderItems() {
    _orderItemBox.removeAll();
  }

  // Game Sessions
  Stream<Query<GameSession>> watchGameSessions() {
    return _gameSessionBox.query().watch();
  }

  List<GameSession> getGameSessionsByDateRange(
      DateTime start, DateTime end, int? userId) {
    Condition<GameSession> gameCondition = GameSession_.startTime
        .between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch)
        .and(GameSession_.status.equals(1)); // Completed only

    if (userId != null) {
      gameCondition =
          gameCondition.and(GameSession_.attributedUserId.equals(userId));
    }

    final gameQuery = _gameSessionBox.query(gameCondition).build();
    final periodGames = gameQuery.find();
    gameQuery.close();

    return periodGames;
  }
}
