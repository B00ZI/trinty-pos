import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_post.dart';
import '../models/game_session.dart';
import '../models/party_tier.dart';
import '../models/app_user.dart';
import '../objectbox.dart';
import '../service/game_session_service.dart';
import '../service/auth_service.dart';
import '../service/printer_helper.dart';
import '../service/notification_service.dart';
import '../widgets/user_selection_dialog.dart';

class GamesScreen extends StatefulWidget {
  final ObjectBox objectbox;
  const GamesScreen({super.key, required this.objectbox});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSession(GamePost post) async {
    final tiers = widget.objectbox.partyTierBox.getAll();
    if (tiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez d\'abord configurer des paliers dans les paramètres')));
      return;
    }

    final tier = await showModalBottomSheet<PartyTier>(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: tiers.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(tiers[index].label),
          subtitle: Text('${tiers[index].price.toStringAsFixed(2)} DH'),
          onTap: () => Navigator.pop(context, tiers[index]),
        ),
      ),
    );

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
      }

      final session = await GameSessionService.startSession(
        post: post,
        tier: tier,
        userId: userId,
        objectbox: widget.objectbox,
      );

      // Trigger Print
      PrinterHelper.printGameTicket(session, widget.objectbox);
      
      // Schedule notification
      NotificationService.scheduleSessionEnd(session);
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
              onTap: () {
                Navigator.pop(context);
                GameSessionService.endSession(session, widget.objectbox);
                NotificationService.cancelSessionNotification(session.id);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('Annuler la partie'),
              onTap: () {
                Navigator.pop(context);
                GameSessionService.cancelSession(session, widget.objectbox);
                NotificationService.cancelSessionNotification(session.id);
                setState(() {});
              },
            ),
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
        stream: widget.objectbox.gamePostBox.query().watch(triggerImmediately: true).map((q) => q.find()),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final posts = snapshot.data!;
          if (posts.isEmpty) return const Center(child: Text('Aucun poste configuré. Allez dans Paramètres > Jeux.'));

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
              GameSession? session;
              if (post.isActive) {
                session = GameSessionService.getActiveSessionForPost(post.id, widget.objectbox);
              }

              final isBusy = post.isActive && session != null;
              final Color color = isBusy ? Colors.orange.shade100 : Colors.green.shade100;
              final Color textColor = isBusy ? Colors.orange.shade900 : Colors.green.shade900;

              Duration remaining = Duration.zero;
              bool isExpired = false;
              if (isBusy && !session.isOpenSession) {
                remaining = session.endTime.difference(DateTime.now());
                if (remaining.isNegative) {
                  remaining = Duration.zero;
                  isExpired = true;
                }
              }

              return InkWell(
                onTap: isBusy ? () => _manageSession(session!) : () => _startSession(post),
                child: Card(
                  color: color,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(post.label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 8),
                        if (isBusy) ...[
                          Text('Partie #${session.partyNumber}', style: TextStyle(color: textColor)),
                          const SizedBox(height: 8),
                          if (session.isOpenSession)
                            Text('OUVERT', style: TextStyle(fontWeight: FontWeight.bold, color: textColor))
                          else
                            Text(
                              _formatDuration(remaining),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isExpired ? Colors.red : textColor,
                              ),
                            ),
                        ] else
                          Text('DISPONIBLE', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
