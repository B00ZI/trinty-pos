import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';

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
    final orderUserId = order.user.target?.id;
    final currentUserId = widget.currentUser?.id;
    final isOwnOrder = orderUserId == null || currentUserId == orderUserId;

    if (!isOwnOrder) {
      final isAdmin = await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.danger,
              content: const Row(
                children: [
                  Icon(Icons.lock_outline, color: AppColors.surface0, size: 18),
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
    final extrasMultiplier = item.isPerUnitExtras ? item.quantity : 1;
    for (final extra in item.resolveExtras()) {
      itemTotal += extra.price * extra.quantity * extrasMultiplier;
    }
    return itemTotal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface1,
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface0,
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink5.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      color: AppColors.ink0,
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: BusinessDayFilter(
                        selectedDate: _selectedBusinessDay,
                        onDateChanged: (date) {
                          setState(() {
                            _selectedBusinessDay = date;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildUnifiedFeed(),
          ),
        ],
      ),
      floatingActionButton: _SpeedDialFAB(
        onToggleDeleted: _toggleDeletedOrders,
        onPrintBrief: _printDayBrief,
        showDeleted: _showDeletedOrders,
      ),
    );
  }

  void _toggleDeletedOrders() async {
    if (!_showDeletedOrders) {
      final isAdmin = await AdminPinDialog.verify(context, ref.read(objectBoxProvider));
      if (isAdmin) {
        setState(() => _showDeletedOrders = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.danger,
              content: const Row(
                children: [
                  Icon(Icons.lock_outline, color: AppColors.surface0, size: 18),
                  SizedBox(width: 8),
                  Text('Accès refusé : Admin requis'),
                ],
              ),
            ),
          );
        }
      }
    } else {
      setState(() => _showDeletedOrders = false);
    }
  }

  void _printDayBrief() async {
    try {
      await PrinterHelper.printDayBrief(
        _selectedBusinessDay,
        ref.read(objectBoxProvider),
        _config,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.surface0, size: 18),
                SizedBox(width: 8),
                Text('Rapport journalier imprimé'),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.surface0, size: 18),
                const SizedBox(width: 8),
                Text('Erreur: $e'),
              ],
            ),
          ),
        );
      }
    }
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

            final List<dynamic> combined = [];

            final filteredOrders = _showDeletedOrders
                ? orders
                : orders.where((o) => !o.isDeleted).toList();
            combined.addAll(filteredOrders);

            final unlinkedSessions = sessions
                .where((s) => s.relatedOrderId == null || s.relatedOrderId == 0)
                .toList();
            combined.addAll(unlinkedSessions);

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
                    const Icon(Icons.inbox_outlined,
                        size: 56, color: AppColors.ink4),
                    const SizedBox(height: AppSpacing.space3),
                    const Text(
                      'Aucune activité pour cette journée',
                      style: TextStyle(
                        color: AppColors.ink3,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.space2, horizontal: AppSpacing.space1),
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
      statusColor = AppColors.success;
      statusLabel = 'Terminée';
      statusIcon = Icons.check_circle_outline;
    } else if (session.status == 2) {
      statusColor = AppColors.danger;
      statusLabel = 'Annulée';
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColor = AppColors.info;
      statusLabel = 'En cours';
      statusIcon = Icons.play_circle_outline;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space2, vertical: AppSpacing.space1 + 2),
      color: AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.rLg,
        side: const BorderSide(color: AppColors.surface3),
      ),
      child: InkWell(
        borderRadius: AppRadius.rLg,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Options de la partie'),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    PrinterHelper.printGameTicket(
                        session, ref.read(objectBoxProvider));
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
          padding: const EdgeInsets.all(AppSpacing.space3 + 1),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.space2 + 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppRadius.rMd,
                ),
                child: const Icon(Icons.sports_esports_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.postLabel} - Partie #${session.partyNumber}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: AppSpacing.space1),
                    Text(
                      'Palier : ${session.tierLabel}  •  Staff : $user',
                      style: const TextStyle(
                          color: AppColors.ink2, fontSize: 12.5),
                    ),
                    const SizedBox(height: AppSpacing.space0 + 2),
                    Text(
                      'Début : ${DateFormat('HH:mm').format(session.startTime)}   Fin : ${session.endTime != null ? DateFormat('HH:mm').format(session.endTime!) : "Ouvert"}',
                      style: const TextStyle(
                          color: AppColors.ink3, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.space2),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${session.currentCalculatedPrice.toStringAsFixed(2)} DH',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: AppSpacing.space1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.space2,
                        vertical: AppSpacing.space1 - 1),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: AppRadius.rFull,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: AppSpacing.space1),
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
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space2, vertical: AppSpacing.space1 + 2),
      color: order.isDeleted ? AppColors.dangerLight : AppColors.surface0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.rLg,
        side: BorderSide(
          color: order.isDeleted ? AppColors.danger : AppColors.surface3,
          width: order.isDeleted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.space2 + 2),
                  decoration: BoxDecoration(
                    color: order.isDeleted
                        ? AppColors.dangerLight
                        : AppColors.successLight,
                    borderRadius: AppRadius.rMd,
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: order.isDeleted
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                ),
                const SizedBox(width: AppSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Commande N° ${order.orderNumber}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                      if (order.isEdited || order.isDeleted)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.space1 + 2),
                          child: Wrap(
                            spacing: AppSpacing.space1 + 2,
                            children: [
                              if (order.isEdited)
                                _buildBadge('MODIFIÉE', AppColors.warning),
                              if (order.isDeleted)
                                _buildBadge('SUPPRIMÉE', AppColors.danger),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined,
                      color: order.isDeleted
                          ? AppColors.ink4
                          : AppColors.primary),
                  onPressed: order.isDeleted ? null : () => _editOrder(order),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: order.isDeleted ? AppColors.ink4 : AppColors.danger),
                  onPressed:
                      order.isDeleted ? null : () => _deleteOrder(order),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            const Divider(height: AppSpacing.space6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 15, color: AppColors.ink3),
                const SizedBox(width: AppSpacing.space1 + 2),
                Flexible(
                  child: Text(
                    order.date.toLocal().toString().split('.')[0],
                    style: const TextStyle(color: AppColors.ink2, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space1),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 15, color: AppColors.ink3),
                const SizedBox(width: AppSpacing.space1 + 2),
                Flexible(
                  child: Text(
                    'Staff : ${order.user.target?.name ?? "Inconnu"}',
                    style: const TextStyle(color: AppColors.ink2, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space1),
            Row(
              children: [
                const Icon(Icons.shopping_bag_outlined,
                    size: 15, color: AppColors.ink3),
                const SizedBox(width: AppSpacing.space1 + 2),
                Text(
                  'Articles : ${order.items.length}',
                  style: const TextStyle(color: AppColors.ink2, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '${order.items.fold<double>(0, (sum, item) => sum + calculateItemTotal(item)).toStringAsFixed(2)} DH',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space3),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.space3),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadius.rMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Articles :',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: AppColors.ink2)),
                  const SizedBox(height: AppSpacing.space1 + 2),
                  for (final item in order.items)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.space1 + 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '• ${item.productName ?? item.product.target?.name ?? 'Produit Supprimé'}  ${item.price ?? 'N/A'} x ${item.quantity}',
                              style: const TextStyle(fontSize: 13.5),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          if (item.resolveExtras().isNotEmpty)
                            ...item.resolveExtras().map((extra) {
                              final qty = extra.quantity *
                                  (item.isPerUnitExtras ? item.quantity : 1);
                              return Padding(
                                padding: const EdgeInsets.only(
                                    left: AppSpacing.space4, top: AppSpacing.space0 + 2),
                                child: Text(
                                  '+ ${extra.name} ${qty > 1 ? "x$qty" : ""} : ${(extra.price * qty).toStringAsFixed(2)} DH',
                                  style: const TextStyle(
                                      fontSize: 11.5, color: AppColors.ink3),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space3),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: order.isDeleted ? null : () => _printOrder(order),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Imprimer'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: AppColors.surface0,
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.rMd),
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
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space2, vertical: AppSpacing.space1 - 1),
      decoration:
          BoxDecoration(color: color, borderRadius: AppRadius.rFull),
      child: Text(text,
          style: const TextStyle(
              color: AppColors.surface0,
              fontWeight: FontWeight.bold,
              fontSize: 10)),
    );
  }

  void _editOrder(order_model.Order order) async {
    final orderUserId = order.user.target?.id;
    final currentUserId = widget.currentUser?.id;
    final isOwnOrder = orderUserId == null || currentUserId == orderUserId;

    if (!isOwnOrder) {
      final isAdmin = await AdminPinDialog.verify(
          context, ref.read(objectBoxProvider));
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.danger,
              content: const Row(
                children: [
                  Icon(Icons.lock_outline,
                      color: AppColors.surface0, size: 18),
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
          builder: (context) =>
              custom_order_screen.OrderScreen(orderToEdit: order),
        ),
      ).then((_) => setState(() {}));
    }
  }

  void _printOrder(order_model.Order order) {
    final receiptData = ReceiptData.convertRuciToReceiptData(order);
    PrinterHelper.printReceipt(receiptData, ref.read(objectBoxProvider));
  }
}

class _SpeedDialFAB extends StatefulWidget {
  final VoidCallback onToggleDeleted;
  final VoidCallback onPrintBrief;
  final bool showDeleted;

  const _SpeedDialFAB({
    required this.onToggleDeleted,
    required this.onPrintBrief,
    required this.showDeleted,
  });

  @override
  State<_SpeedDialFAB> createState() => _SpeedDialFABState();
}

class _SpeedDialFABState extends State<_SpeedDialFAB>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: _expandAnimation.value,
                  child: Opacity(
                    opacity: _expandAnimation.value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FloatingActionButton.small(
                        heroTag: 'print_brief',
                        backgroundColor: AppColors.ink0,
                        onPressed: () {
                          _toggle();
                          widget.onPrintBrief();
                        },
                        child: const Icon(Icons.print, color: AppColors.surface0, size: 20),
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: _expandAnimation.value,
                  child: Opacity(
                    opacity: _expandAnimation.value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FloatingActionButton.small(
                        heroTag: 'deleted_orders',
                        backgroundColor: widget.showDeleted
                            ? AppColors.danger
                            : AppColors.ink1,
                        onPressed: () {
                          _toggle();
                          widget.onToggleDeleted();
                        },
                        child: Icon(
                          widget.showDeleted
                              ? Icons.visibility_off
                              : Icons.delete_outline,
                          color: AppColors.surface0,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        FloatingActionButton(
          heroTag: 'main_speed_dial',
          backgroundColor: AppColors.primary,
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add, color: AppColors.surface0, size: 28),
          ),
        ),
      ],
    );
  }
}
