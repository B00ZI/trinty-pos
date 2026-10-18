import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/game_post.dart';
import '../models/game_session.dart';
import '../models/app_user.dart';
import '../objectbox.g.dart';
import '../service/game_session_service.dart';
import '../service/auth_service.dart';
import '../service/printer_helper.dart';
import '../widgets/user_selection_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../models/order.dart' as order_model;
import '../models/order_item.dart';
import '../models/order_counter.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';

class GamesScreen extends ConsumerStatefulWidget {
  final AppUser? assignedUser;
  const GamesScreen({super.key, this.assignedUser});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _checkLimitedSessions();
        setState(() {});
      }
    });
  }

  void _checkLimitedSessions() {
    final activeSessions = ref.read(objectBoxProvider).gameSessionBox
        .query(GameSession_.status.equals(0))
        .build()
        .find();

    for (final session in activeSessions) {
      if (session.isLimitedDuration) {
        final endAt = session.startTime
            .add(Duration(minutes: session.limitedDurationMinutes));
        if (DateTime.now().isAfter(endAt)) {
          GameSessionService.endSession(session, ref.read(objectBoxProvider));
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _showDurationSelection(GamePost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Choisir la durée pour ${post.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('1 Heure'),
              onTap: () {
                Navigator.pop(context);
                _startFixedDurationSession(post, 60);
              },
            ),
            ListTile(
              title: const Text('30 Minutes'),
              onTap: () {
                Navigator.pop(context);
                _startFixedDurationSession(post, 30);
              },
            ),
            ListTile(
              title: const Text('15 Minutes'),
              onTap: () {
                Navigator.pop(context);
                _startFixedDurationSession(post, 15);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startFixedDurationSession(GamePost post, int minutes) async {
    final tiers = ref.read(objectBoxProvider).partyTierBox.getAll();
    if (tiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Veuillez d\'abord configurer des paliers dans les paramètres')));
      return;
    }
    final tier = tiers.first;

    int? userId;
    final authMode = await AuthService.getAuthMode();
    if (authMode == AuthMode.perOrder) {
      final user = await showDialog<AppUser>(
        context: context,
        builder: (context) => UserSelectionDialog(objectbox: ref.read(objectBoxProvider)),
      );
      if (user == null) return;
      userId = user.id;
    } else if (authMode == AuthMode.session) {
      userId = widget.assignedUser?.id;
    }

    final price = (minutes / 60.0) * tier.ratePerHour;

    // Create Order directly
    final orderCounterBox = ref.read(objectBoxProvider).store.box<OrderCounter>();
    final orderBox = ref.read(objectBoxProvider).store.box<order_model.Order>();

    final orderCounter = orderCounterBox.isEmpty()
        ? OrderCounter(id: 1, value: 1)
        : orderCounterBox.getAll().first;
    final order = order_model.Order(
      date: DateTime.now(),
      orderNumber: orderCounter.value,
    );
    if (userId != null) {
      final user = ref.read(objectBoxProvider).userBox.get(userId);
      if (user != null) order.user.target = user;
    }

    final item = OrderItem(quantity: 1);
    item.price = price;
    item.productName = 'Jeu (${minutes}min): ${post.label}';
    order.items.add(item);

    // P12: order + counter must commit together — all or nothing.
    ref.read(objectBoxProvider).store.runInTransaction(TxMode.write, () {
      orderBox.put(order);
      orderCounter.value += 1;
      orderCounterBox.put(orderCounter);
    });

    // Start Session
    final session = await GameSessionService.startSession(
      post: post,
      tier: tier,
      userId: userId,
      objectbox: ref.read(objectBoxProvider),
      durationMinutes: minutes,
    );
    session.relatedOrderId = order.id;
    ref.read(objectBoxProvider).gameSessionBox.put(session);

    PrinterHelper.printSessionStartTicket(session, ref.read(objectBoxProvider));
    setState(() {});
  }

  void _startSession(GamePost post, {bool isQueue = false}) async {
    final tiers = ref.read(objectBoxProvider).partyTierBox.getAll();
    if (tiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Veuillez d\'abord configurer des paliers dans les paramètres')));
      return;
    }

    final tier = tiers.first;
    int? userId;
      final authMode = await AuthService.getAuthMode();
      if (authMode == AuthMode.perOrder) {
        final user = await showDialog<AppUser>(
          context: context,
          builder: (context) =>
              UserSelectionDialog(objectbox: ref.read(objectBoxProvider)),
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
          objectbox: ref.read(objectBoxProvider),
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Partie mise en attente pour ${post.label}')));
      } else {
        final session = await GameSessionService.startSession(
          post: post,
          tier: tier,
          userId: userId,
          objectbox: ref.read(objectBoxProvider),
        );
        PrinterHelper.printSessionStartTicket(session, ref.read(objectBoxProvider));
      }
      setState(() {});
  }

  void _manageSession(GameSession session) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Partie #${session.partyNumber} - ${session.postLabel}',
                style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: AppSpacing.space2),
            Text('Palier : ${session.tierLabel}'),
            if (session.isLimitedDuration ||
                session.relatedOrderId != null) ...[
              SizedBox(height: AppSpacing.space1),
              Text(
                'Durée Prédéfinie : ${session.limitedDurationMinutes > 0 ? "${session.limitedDurationMinutes} min" : "Payée d\'avance"}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.info),
              ),
            ],
            SizedBox(height: AppSpacing.space4),
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Réimprimer Ticket'),
              onTap: () {
                Navigator.pop(context);
                PrinterHelper.printGameTicket(session, ref.read(objectBoxProvider));
              },
            ),
            ListTile(
              leading: const Icon(Icons.stop, color: AppColors.danger),
              title: const Text('Terminer la partie'),
              onTap: () async {
                Navigator.pop(context);

                // If it's a prepaid session (either by flag or because an order is already linked)
                if (session.isLimitedDuration ||
                    session.relatedOrderId != null) {
                  GameSessionService.endSession(session, ref.read(objectBoxProvider));
                  setState(() {});
                  return;
                }

                final price = session.currentCalculatedPrice;
                final duration = DateTime.now().difference(session.startTime);
                final sessionDetails =
                    'Temps écoulé: ${_formatDuration(duration)}\nTarif: ${session.ratePerHour} DH/H';
                final paymentConfirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => PaymentDialog(
                        totalAmount: price,
                        sessionDetails: sessionDetails,
                        isGameSession: true,
                      ),
                    ) ??
                    false;

                if (paymentConfirmed) {
                  final orderCounterBox =
                      ref.read(objectBoxProvider).store.box<OrderCounter>();
                  final orderBox =
                      ref.read(objectBoxProvider).store.box<order_model.Order>();

                  final orderCounter = orderCounterBox.isEmpty()
                      ? OrderCounter(id: 1, value: 1)
                      : orderCounterBox.getAll().first;
                  final order = order_model.Order(
                    date: DateTime.now(),
                    orderNumber: orderCounter.value,
                  );
                  if (session.attributedUserId != null) {
                    final user =
                        ref.read(objectBoxProvider).userBox.get(session.attributedUserId!);
                    if (user != null) {
                      order.user.target = user;
                    }
                  }

                  final item = OrderItem(quantity: 1);
                  item.price = price;
                  item.productName = 'Jeu: ${session.postLabel}';
                  order.items.add(item);

                  // P12: order + counter must commit together — all or nothing.
                  ref.read(objectBoxProvider).store.runInTransaction(TxMode.write, () {
                    orderBox.put(order);
                    orderCounter.value += 1;
                    orderCounterBox.put(orderCounter);
                  });

                  GameSessionService.endSession(session, ref.read(objectBoxProvider),
                      relatedOrderId: order.id);
                  PrinterHelper.printGameTicket(session, ref.read(objectBoxProvider));
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
      backgroundColor: AppColors.surface1,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
              decoration: const BoxDecoration(
                color: AppColors.surface0,
                border: Border(bottom: BorderSide(color: AppColors.surface3, width: 1)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: AppColors.ink0,
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  const Expanded(
                    child: Text(
                      'Postes de Jeu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink0,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<GamePost>>(
        stream: ref.read(objectBoxProvider).gamePostBox
            .query()
            .watch(triggerImmediately: true)
            .map((q) => q.find()),
        builder: (context, postSnapshot) {
          if (!postSnapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final posts = postSnapshot.data!;
          if (posts.isEmpty)
            return const Center(
                child: Text(
                    'Aucun poste configuré. Allez dans Paramètres > Jeux.'));

          return StreamBuilder<List<GameSession>>(
            stream: ref.read(objectBoxProvider).gameSessionBox
                .query(GameSession_.status.equals(0))
                .watch(triggerImmediately: true)
                .map((q) => q.find()),
            builder: (context, sessionSnapshot) {
              final activeSessions = sessionSnapshot.data ?? [];
              final sessionMap = {
                for (var s in activeSessions) s.post.targetId: s
              };

              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth < 600
                      ? 2
                      : constraints.maxWidth < 900
                          ? 3
                          : 4;

                  return GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.space4),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: AppSpacing.space4,
                      mainAxisSpacing: AppSpacing.space4,
                    ),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      final session = sessionMap[post.id];

                      final isBusy = post.isActive && session != null;
                      final isPrepaid = isBusy &&
                          (session.isLimitedDuration ||
                              session.relatedOrderId != null);

                      final Color color = isPrepaid
                          ? AppColors.infoLight
                          : (isBusy
                              ? AppColors.warningLight
                              : AppColors.successLight);
                      final Color textColor = isPrepaid
                          ? AppColors.info
                          : (isBusy
                              ? AppColors.warning
                              : AppColors.success);

                      Duration remaining = Duration.zero;
                      if (isBusy) {
                        remaining = DateTime.now().difference(session.startTime);
                      }

                      return StreamBuilder<List<GameSession>>(
                        stream: ref.read(objectBoxProvider).gameSessionBox
                            .query(GameSession_.post
                                .equals(post.id)
                                .and(GameSession_.status.equals(3)))
                            .watch(triggerImmediately: true)
                            .map((q) => q.find()),
                        builder: (context, queueSnapshot) {
                          final queuedSessions = queueSnapshot.data ?? [];

                          return InkWell(
                            onTap: isBusy
                                ? () => _manageSession(session)
                                : () => _startSession(post),
                            onLongPress:
                                isBusy ? null : () => _showDurationSelection(post),
                            child: Card(
                              color: color,
                              elevation: isBusy ? 4 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppRadius.rMd,
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(AppSpacing.space3),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(post.label,
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: textColor),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        SizedBox(height: AppSpacing.space1),
                                        if (isBusy) ...[
                                          Text('Partie #${session.partyNumber}',
                                              style: TextStyle(
                                                  color: textColor, fontSize: 12)),
                                          SizedBox(height: AppSpacing.space1),
                                          Text(
                                            session.isLimitedDuration
                                                ? _formatDuration(() {
                                                    final diff = session.startTime
                                                        .add(Duration(
                                                            minutes: session
                                                                .limitedDurationMinutes))
                                                        .difference(DateTime.now());
                                                    return diff.isNegative
                                                        ? Duration.zero
                                                        : diff;
                                                  }())
                                                : _formatDuration(remaining),
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
                                            ),
                                          ),
                                          Text(
                                              '${session.currentCalculatedPrice.toStringAsFixed(2)} DH',
                                              style: TextStyle(
                                                  color: textColor, fontSize: 14)),
                                          if (queuedSessions.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: AppSpacing.space1),
                                              child: Text(
                                                'Suivant: #${queuedSessions.first.partyNumber}',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        textColor.withOpacity(0.7)),
                                              ),
                                            ),
                                        ] else
                                          Text('DISPONIBLE',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: textColor,
                                                  fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  if (isBusy)
                                    Positioned(
                                      top: AppSpacing.space1,
                                      right: AppSpacing.space1,
                                      child: IconButton(
                                        icon: const Icon(Icons.add_circle_outline,
                                            size: 20),
                                        onPressed: () =>
                                            _startSession(post, isQueue: true),
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
          );
        },
      ),
            ),
          ],
        ),
      ),
    );
  }
}
