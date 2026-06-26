import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/profile_provider.dart';
import '../../state/report_provider.dart';
import '../capture/capture_screen.dart';
import '../exercise/exercise_screen.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../profile/profile_screen.dart';
import '../social/social_screen.dart';

/// The signed-in shell: bottom navigation across Today / Exercise / History /
/// Profile, with a prominent center button for the capture flow.
///
/// Capture is a FAB rather than a tab because it's a push-and-return flow, not a
/// persistent destination. On first run with an incomplete profile, it nudges
/// the user into onboarding (skippable).
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _index = 0;
  bool _onboardingChecked = false;

  static const _tabs = [
    HomeScreen(),
    SocialScreen(),
    ExerciseScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
  }

  Future<void> _maybeOnboard() async {
    if (_onboardingChecked) return;
    _onboardingChecked = true;
    try {
      final profile = await ref.read(profileApiProvider).get();
      if (!profile.isComplete && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
        ref.invalidate(profileProvider);
        ref.invalidate(todayReportProvider);
      }
    } catch (_) {
      // Network/profile errors here are non-fatal; the user can still use the
      // app and finish their profile from the Profile tab.
    }
  }

  Future<void> _openCapture() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
    // A meal may have been logged — refresh today's view.
    ref.invalidate(todayReportProvider);
    if (mounted) setState(() => _index = 0); // land back on Today
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCapture,
        tooltip: 'Log a meal',
        child: const Icon(Icons.add_a_photo),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Today'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups),
              label: 'Community'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: 'Exercise'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
