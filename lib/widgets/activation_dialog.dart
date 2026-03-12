import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../service/activation_service.dart';

class ActivationDialog extends StatefulWidget {
  final VoidCallback onActivated;

  const ActivationDialog({super.key, required this.onActivated});

  @override
  State<ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends State<ActivationDialog> {
  final _keyController = TextEditingController();
  String _androidId = "Chargement...";
  bool _isValidating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAndroidId();
    ActivationService.getAndroidId().then((id) {
      print("Android ID: $id");
    });
  }

  Future<void> _loadAndroidId() async {
    final id = await ActivationService.getAndroidId();
    if (mounted) {
      setState(() {
        _androidId = id;
      });
    }
  }

  Future<void> _handleActivation() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _errorMessage = "Veuillez entrer la clé d'activation");
      return;
    }

    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    // Small delay for UI feedback
    await Future.delayed(const Duration(milliseconds: 500));

    final isValid = await ActivationService.verifyKey(key);

    if (isValid) {
      await ActivationService.saveActivationKey(key);
      widget.onActivated();
    } else {
      if (mounted) {
        setState(() {
          _isValidating = false;
          _errorMessage = "Clé invalide pour cet appareil. Veuillez réessayer.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // Prevent dismissing the dialog
      child: AlertDialog(
        title: const Text("Activation de l'application"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Votre application n'est pas activée. Veuillez envoyer l'identifiant Android suivant à votre fournisseur pour recevoir une clé d'activation :",
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _androidId,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _androidId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("Identifiant copié dans le presse-papiers")),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Entrez la clé d'activation :",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _keyController,
                decoration: InputDecoration(
                  hintText: "Collez votre clé ici",
                  errorText: _errorMessage,
                  border: const OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: _isValidating ? null : _handleActivation,
            child: _isValidating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Activer Maintenant"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }
}
