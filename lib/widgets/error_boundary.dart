import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A widget that catches errors in its subtree and displays a friendly
/// error screen instead of crashing the app.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? label;

  const ErrorBoundary({super.key, required this.child, this.label});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
  }

  void _reset() {
    setState(() {
      _error = null;
      _stackTrace = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorScreen(
        error: _error!,
        stackTrace: _stackTrace,
        label: widget.label,
        onRetry: _reset,
      );
    }

    return _ErrorBoundaryScope(
      onError: (error, stack) {
        setState(() {
          _error = error;
          _stackTrace = stack;
        });
      },
      child: widget.child,
    );
  }
}

class _ErrorBoundaryScope extends InheritedWidget {
  final void Function(Object error, StackTrace stack) onError;

  const _ErrorBoundaryScope({
    required this.onError,
    required super.child,
  });

  static _ErrorBoundaryScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ErrorBoundaryScope>();
  }

  @override
  bool updateShouldNotify(_ErrorBoundaryScope oldWidget) {
    return onError != oldWidget.onError;
  }
}

/// Report an error to the nearest ErrorBoundary ancestor.
void reportError(BuildContext context, Object error, [StackTrace? stack]) {
  final scope = _ErrorBoundaryScope.of(context);
  if (scope != null) {
    scope.onError(error, stack ?? StackTrace.current);
  } else {
    // No boundary found – log and show snackbar
    debugPrint('Unhandled error (no ErrorBoundary): $error');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $error')),
      );
    }
  }
}

class _ErrorScreen extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final String? label;
  final VoidCallback onRetry;

  const _ErrorScreen({
    required this.error,
    this.stackTrace,
    this.label,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(label ?? 'Erreur'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                'Une erreur est survenue',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink3,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
