import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/admin_pin_dialog.dart';
import '../models/order_item.dart';
import '../objectbox.dart';
import '../objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import '../models/order.dart';
import '../models/printer_config.dart';
import '../models/order_counter.dart';
import '../widgets/dialog.dart' as custom_dialog;
import '../service/printer_helper.dart';
import 'order_screen.dart' as custom_order_screen;
import '../service/business_day_helper.dart';
import 'package:intl/intl.dart';
import '../widgets/business_day_filter.dart';
import '../models/store_config.dart';
import '../models/game_session.dart';
import '../models/app_user.dart';

class HistoryScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const HistoryScreen({super.key, required this.objectbox});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final Box<Ruci> _orderBox;
  late final Box<PrinterConfig> _printerConfigBox;
  late final Box<OrderCounter> _orderCounterBox;
  late final Box<StoreConfig> _storeConfigBox;
  bool _showDeletedOrders = false;
  DateTime _selectedBusinessDay = DateTime.now();
  late StoreConfig _config;

  @override
  void initState() {
    super.initState();
    _orderBox = widget.objectbox.store.box<Ruci>();
    _printerConfigBox = widget.objectbox.store.box<PrinterConfig>();
    _orderCounterBox = widget.objectbox.store.box<OrderCounter>();
    _storeConfigBox = widget.objectbox.store.box<StoreConfig>();
    _loadStoreConfig();
  }

  void _loadStoreConfig() {
    final configs = _storeConfigBox.getAll();
    _config = configs.isNotEmpty ? configs.first : StoreConfig();
    _selectedBusinessDay =
        BusinessDayHelper.getBusinessDayDate(DateTime.now(), _config);
  }

  Future<void> _deleteOrder(Ruci order) async {
    order.isDeleted = true;
    _orderBox.put(order);
  }

  void _resetOrderCounter() {
    OrderCounter? orderCounter = _orderCounterBox.get(1);
    if (orderCounter == null) {
      orderCounter = OrderCounter(id: 1, value: 1);
    } else {
      orderCounter.value = 1;
    }
    _orderCounterBox.put(orderCounter);
  }

  Stream<List<GameSession>> _getGameSessionsStream() {
    final range = BusinessDayHelper.getBusinessDayRange(_selectedBusinessDay, _config);
    return widget.objectbox.gameSessionBox
        .query(GameSession_.startTime.between(
            range.$1.millisecondsSinceEpoch,
            range.$2.millisecondsSinceEpoch))
        .watch(triggerImmediately: true)
        .map((q) => q.find());
  }

  Stream<List<Ruci>> _getOrdersStream() {
    final range = BusinessDayHelper.getBusinessDayRange(_selectedBusinessDay, _config);
    return _orderBox
        .query(Ruci_.date.between(
            range.$1.millisecondsSinceEpoch,
            range.$2.millisecondsSinceEpoch))
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
                final isAdmin = await AdminPinDialog.verify(context, widget.objectbox);
                if (isAdmin) {
                  setState(() => _showDeletedOrders = true);
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Accès refusé : Admin requis')),
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
    return StreamBuilder<List<Ruci>>(
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
            final unlinkedSessions = sessions.where((s) => s.relatedOrderId == null || s.relatedOrderId == 0).toList();
            combined.addAll(unlinkedSessions);

            // Sort by time descending
            combined.sort((a, b) {
              final DateTime timeA = (a is Ruci) 
                  ? a.date
                  : (a as GameSession).startTime;
              final DateTime timeB = (b is Ruci)
                  ? b.date
                  : (b as GameSession).startTime;
              return timeB.compareTo(timeA);
            });

            if (combined.isEmpty) {
              return const Center(child: Text('Aucune activité pour cette journée'));
            }

            return ListView.builder(
              itemCount: combined.length,
              itemBuilder: (context, index) {
                final item = combined[index];
                if (item is Ruci) {
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
    final user = session.attributedUserId != null
        ? widget.objectbox.userBox.get(session.attributedUserId!)?.name ??
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
                    PrinterHelper.printGameTicket(session, widget.objectbox);
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

  Widget _buildOrderCard(Ruci order) {
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

  void _editOrder(Ruci order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => custom_order_screen.OrderScreen(
            objectbox: widget.objectbox, orderToEdit: order),
      ),
    ).then((_) => setState(() {}));
  }

  void _printOrder(Ruci order) {
    final receiptData = ReceiptData.convertRuciToReceiptData(order);
    PrinterHelper.printReceipt(receiptData, widget.objectbox);
  }
}