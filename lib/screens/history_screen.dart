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
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade600,
              content: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seul un administrateur peut supprimer les commandes des autres',
                    ),
                  ),
                ],
              ),
            ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(
          'Historique Unifié',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        scrolledUnderElevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton.filledTonal(
              icon: Icon(
                _showDeletedOrders ? Icons.visibility : Icons.visibility_off,
              ),
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
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Colors.red.shade600,
                          content: const Row(
                            children: [
                              Icon(Icons.lock_outline,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Accès refusé : Admin requis'),
                            ],
                          ),
                        ),
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
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: BusinessDayFilter(
              selectedDate: _selectedBusinessDay,
              onDateChanged: (date) {
                setState(() {
                  _selectedBusinessDay = date;
                });
              },
            ),
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
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 56, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'Aucune activité pour cette journée',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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

    late final Color statusColor;
    late final String statusLabel;
    late final IconData statusIcon;
    if (session.status == 1) {
      statusColor = Colors.green.shade600;
      statusLabel = 'Terminée';
      statusIcon = Icons.check_circle_outline;
    } else if (session.status == 2) {
      statusColor = Colors.red.shade600;
      statusLabel = 'Annulée';
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColor = Colors.blue.shade600;
      statusLabel = 'En cours';
      statusIcon = Icons.play_circle_outline;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Options de la partie'),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    PrinterHelper.printGameTicket(session, ref.read(objectBoxProvider));
                  },
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Réimprimer Ticket'),
                ),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer')),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.sports_esports_outlined,
                    color: Colors.indigo.shade400),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.postLabel} - Partie #${session.partyNumber}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Palier : ${session.tierLabel}  •  Staff : $user',
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 12.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Début : ${DateFormat('HH:mm').format(session.startTime)}   Fin : ${session.endTime != null ? DateFormat('HH:mm').format(session.endTime!) : "Ouvert"}',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${session.currentCalculatedPrice.toStringAsFixed(2)} DH',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(order_model.Order order) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: order.isDeleted ? Colors.red.shade50 : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: order.isDeleted ? Colors.red.shade200 : Colors.blueGrey.shade100,
          width: order.isDeleted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: order.isDeleted
                        ? Colors.red.shade100
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: order.isDeleted
                        ? Colors.red.shade400
                        : Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commande N° ${order.orderNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                      if (order.isEdited || order.isDeleted)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 6,
                            children: [
                              if (order.isEdited)
                                _buildBadge('MODIFIÉE', Colors.orange),
                              if (order.isDeleted)
                                _buildBadge('SUPPRIMÉE', Colors.red),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: order.isDeleted
                          ? Colors.grey
                          : Theme.of(context).colorScheme.secondary),
                  onPressed: order.isDeleted ? null : () => _editOrder(order),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: order.isDeleted ? Colors.grey : Colors.red),
                  onPressed:
                      order.isDeleted ? null : () => _deleteOrder(order),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.schedule, size: 15, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  order.date.toLocal().toString().split('.')[0],
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, size: 15, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Staff : ${order.user.target?.name ?? "Inconnu"}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.shopping_bag_outlined,
                    size: 15, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Articles : ${order.items.length}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '${order.items.fold<double>(0, (sum, item) => sum + calculateItemTotal(item)).toStringAsFixed(2)} DH',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.green),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Articles :',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '• ${item.productName ?? item.product.target?.name ?? 'Produit Supprimé'}  ${item.price ?? 'N/A'} x ${item.quantity}',
                              style: const TextStyle(fontSize: 13.5)),
                          if (item.extras.isNotEmpty)
                            ...item.extras.map((extra) {
                              final qty = item.getExtraQuantity(extra);
                              return Padding(
                                padding: const EdgeInsets.only(left: 16.0, top: 2),
                                child: Text(
                                  '+ ${extra.name} ${qty > 1 ? "x$qty" : ""} : ${(extra.price * qty).toStringAsFixed(2)} DH',
                                  style: TextStyle(
                                      fontSize: 11.5, color: Colors.grey.shade600),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: order.isDeleted ? null : () => _printOrder(order),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Imprimer'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
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
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red.shade600,
              content: const Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seul un administrateur peut modifier les commandes des autres',
                    ),
                  ),
                ],
              ),
            ),
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