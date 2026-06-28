import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/admin_pin_dialog.dart';
import '../models/order_item.dart';
import '../objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import '../models/order.dart' as order_model;
import '../service/printer_helper.dart';
import 'order_screen.dart' as custom_order_screen;
import '../service/business_day_helper.dart';
import 'package:intl/intl.dart';
import '../widgets/business_day_filter.dart';
import '../models/store_config.dart';
import '../models/game_session.dart';
import '../models/app_user.dart';
import '../providers/dashboard_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final AppUser? currentUser;

  const HistoryScreen({super.key, this.currentUser});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late final Box<order_model.Order> _orderBox;
  bool _showDeletedOrders = false;
  DateTime _selectedBusinessDay = DateTime.now();
  StoreConfig _config = StoreConfig();

  @override
  void initState() {
    super.initState();
    final ob = ref.read(objectBoxProvider);
    _orderBox = ob.store.box<order_model.Order>();
    _config = ref.read(configRepositoryProvider).getStoreConfig();
    _selectedBusinessDay =
        BusinessDayHelper.getBusinessDayDate(DateTime.now(), _config);
  }

  Future<void> _deleteOrder(order_model.Order order) async {
    // Check if the order belongs to someone else
    final orderUserId = order.user.target?.id;
    final currentUserId = widget.currentUser?.id;
    final isOwnOrder = orderUserId == null || currentUserId == orderUserId;

    // If deleting someone else's order, require admin PIN
    if (!isOwnOrder) {
      final isAdmin = await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Seul un administrateur peut supprimer les commandes des autres')),
          );
        }
        return;
      }
    }

    order.isDeleted = true;
    _orderBox.put(order);
  }

  Stream<List<GameSession>> _getGameSessionsStream() {
    final range =
        BusinessDayHelper.getBusinessDayRange(_selectedBusinessDay, _config);
    final ob = ref.read(objectBoxProvider);
    return ob.gameSessionBox
        .query(GameSession_.startTime.between(
            range.$1.millisecondsSinceEpoch, range.$2.millisecondsSinceEpoch))
        .watch(triggerImmediately: true)
        .map((q) => q.find());
  }

  Stream<List<order_model.Order>> _getOrdersStream() {
    final range =
        BusinessDayHelper.getBusinessDayRange(_selectedBusinessDay, _config);
    return _orderBox
        .query(Order_.date.between(
            range.$1.millisecondsSinceEpoch, range.$2.millisecondsSinceEpoch))
        .watch(triggerImmediately: true)
        .map((q) => q.find());
  }

  double calculateItemTotal(OrderItem item) {
    double itemTotal =
        (item.price ?? item.product.target?.price ?? 0.0) * item.quantity;
    for (final extra in item.extras) {
      itemTotal += extra.price * item.getExtraQuantity(extra);
    }
    return itemTotal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique Unifié'),
        actions: [
          IconButton(
            icon: Icon(
                _showDeletedOrders ? Icons.visibility : Icons.visibility_off),
            onPressed: () async {
              if (!_showDeletedOrders) {
                // Toggling ON: require admin
                final isAdmin =
                    await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
                if (isAdmin) {
                  setState(() => _showDeletedOrders = true);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Accès refusé : Admin requis')),
                    );
                  }
                }
              } else {
                // Toggling OFF: just do it
                setState(() => _showDeletedOrders = false);
              }
            },
            tooltip: 'Afficher les commandes supprimées',
          ),
        ],
      ),
      body: Column(
        children: [
          BusinessDayFilter(
            selectedDate: _selectedBusinessDay,
            onDateChanged: (date) {
              setState(() {
                _selectedBusinessDay = date;
              });
            },
          ),
          Expanded(
            child: _buildUnifiedFeed(),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedFeed() {
    return StreamBuilder<List<order_model.Order>>(
      stream: _getOrdersStream(),
      builder: (context, orderSnapshot) {
        return StreamBuilder<List<GameSession>>(
          stream: _getGameSessionsStream(),
          builder: (context, sessionSnapshot) {
            if (!orderSnapshot.hasData || !sessionSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = orderSnapshot.data!;
            final sessions = sessionSnapshot.data!;

            // Combine and sort
            final List<dynamic> combined = [];

            // Filter and add orders
            final filteredOrders = _showDeletedOrders
                ? orders
                : orders.where((o) => !o.isDeleted).toList();
            combined.addAll(filteredOrders);

            // Add sessions that aren't linked to an order yet
            final unlinkedSessions = sessions
                .where((s) => s.relatedOrderId == null || s.relatedOrderId == 0)
                .toList();
            combined.addAll(unlinkedSessions);

            // Sort by time descending
            combined.sort((a, b) {
              final DateTime timeA = (a is order_model.Order)
                  ? a.date
                  : (a as GameSession).startTime;
              final DateTime timeB = (b is order_model.Order)
                  ? b.date
                  : (b as GameSession).startTime;
              return timeB.compareTo(timeA);
            });

            if (combined.isEmpty) {
              return const Center(
                  child: Text('Aucune activité pour cette journée'));
            }

            return ListView.builder(
              itemCount: combined.length,
              itemBuilder: (context, index) {
                final item = combined[index];
                if (item is order_model.Order) {
                  return _buildOrderCard(item);
                } else {
                  return _buildPartyCard(item as GameSession);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPartyCard(GameSession session) {
    final ob = ref.read(objectBoxProvider);
    final user = session.attributedUserId != null
        ? ob.userBox.get(session.attributedUserId!)?.name ??
            'Inconnu'
        : 'Système';

    return Card(
      child: ListTile(
        title: Text('${session.postLabel} - Partie #${session.partyNumber}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Palier: ${session.tierLabel} - Staff: $user'),
            Text(
                'Debut: ${DateFormat('HH:mm').format(session.startTime)} - Fin: ${session.endTime != null ? DateFormat('HH:mm').format(session.endTime!) : "Ouvert"}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${session.currentCalculatedPrice.toStringAsFixed(2)} DH',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (session.status == 1)
              const Text('Terminée',
                  style: TextStyle(color: Colors.green, fontSize: 10))
            else if (session.status == 2)
              const Text('Annulée',
                  style: TextStyle(color: Colors.red, fontSize: 10))
            else
              const Text('En cours',
                  style: TextStyle(color: Colors.blue, fontSize: 10)),
          ],
        ),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Options de la partie'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    PrinterHelper.printGameTicket(session, ref.read(objectBoxProvider));
                  },
                  child: const Text('Réimprimer Ticket'),
                ),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer')),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(order_model.Order order) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      color: order.isDeleted
          ? Colors.red.shade50
          : Theme.of(context).colorScheme.surface,
      child: Container(
        decoration: order.isDeleted
            ? BoxDecoration(
                border: Border.all(color: Colors.red.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commande N° ${order.orderNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      if (order.isEdited || order.isDeleted)
                        Row(
                          children: [
                            if (order.isEdited)
                              _buildBadge('MODIFIÉE', Colors.orange),
                            if (order.isDeleted)
                              _buildBadge('SUPPRIMÉE', Colors.red),
                          ],
                        ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.edit,
                        color: order.isDeleted
                            ? Colors.grey
                            : Theme.of(context).colorScheme.secondary),
                    onPressed: order.isDeleted ? null : () => _editOrder(order),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete,
                        color: order.isDeleted ? Colors.grey : Colors.red),
                    onPressed:
                        order.isDeleted ? null : () => _deleteOrder(order),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Date : ${order.date.toLocal().toString().split('.')[0]}'),
              Text('Staff : ${order.user.target?.name ?? "Inconnu"}'),
              Text('Articles : ${order.items.length}'),
              Text(
                'Total : ${order.items.fold<double>(0, (sum, item) => sum + calculateItemTotal(item)).toStringAsFixed(2)} DH',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green),
              ),
              const SizedBox(height: 8),
              const Text('Articles :'),
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '- ${item.productName ?? item.product.target?.name ?? 'Produit Supprimé'} : ${item.price ?? 'N/A'} x ${item.quantity}'),
                      if (item.extras.isNotEmpty)
                        ...item.extras.map((extra) {
                          final qty = item.getExtraQuantity(extra);
                          return Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Text(
                              '  + ${extra.name} ${qty > 1 ? "x$qty" : ""}: ${(extra.price * qty).toStringAsFixed(2)} DH',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        order.isDeleted ? null : () => _printOrder(order),
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  void _editOrder(order_model.Order order) async {
    // Check if the order belongs to someone else
    final orderUserId = order.user.target?.id;
    final currentUserId = widget.currentUser?.id;
    final isOwnOrder = orderUserId == null || currentUserId == orderUserId;

    // If editing someone else's order, require admin PIN
    if (!isOwnOrder) {
      final isAdmin = await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Seul un administrateur peut modifier les commandes des autres')),
          );
        }
        return;
      }
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => custom_order_screen.OrderScreen(
              orderToEdit: order),
        ),
      ).then((_) => setState(() {}));
    }
  }

  void _printOrder(order_model.Order order) {
    final receiptData = ReceiptData.convertRuciToReceiptData(order);
    PrinterHelper.printReceipt(receiptData, ref.read(objectBoxProvider));
  }
}
