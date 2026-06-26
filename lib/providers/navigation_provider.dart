import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents the sections available in the Navigation Hub screen.
enum HubSection {
  order,
  history,
  games,
  dashboard,
  management,
  settings,
}

/// Currently selected section in the Navigation Hub.
final currentHubSectionProvider =
    StateProvider<HubSection>((ref) => HubSection.order);

/// Whether the Games section should be visible (controlled by settings).
final showGamesProvider = StateProvider<bool>((ref) => false);

/// Derived list of enabled hub sections (always includes games check).
final enabledHubSectionsProvider = Provider<List<HubSection>>((ref) {
  final showGames = ref.watch(showGamesProvider);
  return [
    HubSection.order,
    HubSection.history,
    if (showGames) HubSection.games,
    HubSection.dashboard,
    HubSection.management,
    HubSection.settings,
  ];
});
