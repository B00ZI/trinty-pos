import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_post.dart';
import '../models/game_session.dart';
import '../models/party_tier.dart';
import '../models/app_user.dart';
import '../objectbox.dart';
import '../objectbox.g.dart';
import '../service/game_session_service.dart';
import '../service/auth_service.dart';
import '../service/printer_helper.dart';
import '../service/notification_service.dart';
import '../widgets/user_selection_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_counter.dart';

class GamesScreen extends StatefulWidget {
  final ObjectBox objectbox;
  final AppUser? assignedUser;
  const GamesScreen({super.key, required this.objectbox, this.assignedUser});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // _checkAndAutoEndSessions removed
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSession(GamePost post, {bool isQueue = false}) async {
    final tiers = widget.objectbox.partyTierBox.getAll();
    if (tiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez d\'abord configurer des paliers dans les paramètres')));
      return;
    }

    final tier = tiers.first;

    if (tier != null) {
      int? userId;
      final authMode = await AuthService.getAuthMode();
      if (authMode == AuthMode.perOrder) {
        final user = await showDialog<AppUser>(
          context: context,
          builder: (context) => UserSelectionDialog(objectbox: widget.objectbox),
        );
        if (user == null) return;
        userId = user.id;
      } else if (authMode == AuthMode.session) {
        userId = widget.assignedUser?.id;
      }

      if (isQueue) {
        await GameSessionService.queueSession(
          post: post,
          tier: tier,
          userId: userId,
          objectbox: widget.objectbox,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Partie mise en attente pour ${post.label}')));
      } else {
        final session = await GameSessionService.startSession(
          post: post,
          tier: tier,
          userId: userId,
          objectbox: widget.objectbox,
        );
        PrinterHelper.printSessionStartTicket(session, widget.objectbox);
        // NotificationService.scheduleSessionEnd(session); removed
      }
      setState(() {});
    }
  }

  void _manageSession(GameSession session) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Partie #${session.partyNumber} - ${session.postLabel}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Palier : ${session.tierLabel}'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Réimprimer Ticket'),
              onTap: () {
                Navigator.pop(context);
                PrinterHelper.printGameTicket(session, widget.objectbox);
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop, color: Colors.red),
              title: const Text('Terminer la partie'),
              onTap: () async {
                Navigator.pop(context);
                
                final price = session.currentCalculatedPrice;
                final duration = DateTime.now().difference(session.startTime);
                final sessionDetails = 'Temps écoulé: ${_formatDuration(duration)}\nTarif: ${session.ratePerHour} DH/H';
                final paymentConfirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => PaymentDialog(
                    totalAmount: price,
                    sessionDetails: sessionDetails,
                    isGameSession: true,
                  ),
                ) ?? false;
                
                if (paymentConfirmed) {
                  final orderCounterBox = widget.objectbox.store.box<OrderCounter>();
                  final orderBox = widget.objectbox.store.box<Ruci>();
                  
                  final orderCounter = orderCounterBox.isEmpty() ? OrderCounter(id: 1, value: 1) : orderCounterBox.getAll().first;
                  final order = Ruci(
                    date: DateTime.now(),
                    orderNumber: orderCounter.value,
                  );
                  if (session.attributedUserId != null) {
                    final user = widget.objectbox.userBox.get(session.attributedUserId!);
                    if (user != null) {
                      order.user.target = user;
                    }
                  }
                  
                  final item = OrderItem(quantity: 1);
                  item.price = price;
                  item.productName = 'Jeu: ${session.postLabel}';
                  order.items.add(item);
                  
                  orderBox.put(order);
                  
                  orderCounter.value += 1;
                  orderCounterBox.put(orderCounter);

                  GameSessionService.endSession(session, widget.objectbox, relatedOrderId: order.id);
                  // NotificationService.playNotificationSound(); removed
                  PrinterHelper.printGameTicket(session, widget.objectbox);
                  setState(() {});
                }
              },
            ),
// Removed cancel option
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jeux & Postes')),
      body: StreamBuilder<List<GamePost>>(
        stream: widget.objectbox.gamePostBox
            .query()
            .watch(triggerImmediately: true)
            .map((q) => q.find()),
        builder: (context, postSnapshot) {
          if (!postSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          final posts = postSnapshot.data!;
          if (posts.isEmpty) return const Center(child: Text('Aucun poste configuré. Allez dans Paramètres > Jeux.'));

          return StreamBuilder<List<GameSession>>(
            stream: widget.objectbox.gameSessionBox
                .query(GameSession_.status.equals(0))
                .watch(triggerImmediately: true)
                .map((q) => q.find()),
            builder: (context, sessionSnapshot) {
              final activeSessions = sessionSnapshot.data ?? [];
              final sessionMap = {for (var s in activeSessions) s.post.targetId: s};

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final session = sessionMap[post.id];

                  final isBusy = post.isActive && session != null;
                  final Color color = isBusy ? Colors.orange.shade100 : Colors.green.shade100;
                  final Color textColor = isBusy ? Colors.orange.shade900 : Colors.green.shade900;

                  Duration remaining = Duration.zero;
                  if (isBusy) {
                    remaining = DateTime.now().difference(session!.startTime);
                  }

                  return StreamBuilder<List<GameSession>>(
                    stream: widget.objectbox.gameSessionBox
                        .query(GameSession_.post.equals(post.id).and(GameSession_.status.equals(3)))
                        .watch(triggerImmediately: true)
                        .map((q) => q.find()),
                    builder: (context, queueSnapshot) {
                      final queuedSessions = queueSnapshot.data ?? [];
                      
                      return InkWell(
                        onTap: isBusy ? () => _manageSession(session!) : () => _startSession(post),
                        child: Card(
                          color: color,
                          elevation: isBusy ? 4 : 1,
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(post.label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                                    const SizedBox(height: 4),
                                    if (isBusy) ...[
                                      Text('Partie #${session!.partyNumber}', style: TextStyle(color: textColor, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDuration(remaining),
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      Text('${session.currentCalculatedPrice.toStringAsFixed(2)} DH', style: TextStyle(color: textColor, fontSize: 14)),
                                      if (queuedSessions.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            'Suivant: #${queuedSessions.first.partyNumber}',
                                            style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7)),
                                          ),
                                        ),
                                    ] else
                                      Text('DISPONIBLE', style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
                                  ],
                                ),
                              ),
                              if (isBusy)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: () => _startSession(post, isQueue: true),
                                    tooltip: 'Ajouter le prochain tour',
                                    color: textColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
