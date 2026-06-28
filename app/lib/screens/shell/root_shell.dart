import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/profile_provider.dart';
import '../../state/report_provider.dart';
import '../../theme/app_theme.dart';
import '../capture/capture_screen.dart';
import '../exercise/exercise_screen.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../profile/profile_screen.dart';
import '../social/social_screen.dart';

/// The signed-in shell: a floating bottom navigation bar across
/// Community / Exercise / Today / History / Profile, with Today in the center
/// (the default landing tab) and a button for the capture flow.
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
  // Today sits in the center (index 2) and is where the app opens.
  int _index = 2;
  bool _onboardingChecked = false;

  // Order matches the nav destinations below: Today is centered at index 2.
  static const _tabs = [
    SocialScreen(),
    ExerciseScreen(),
    HomeScreen(),
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
    if (mounted) setState(() => _index = 2); // land back on Today (center)
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
      // Floating bar with 5 fixed tabs. The selected tab lifts into a raised
      // coral circle that pops above the bar (see example.png). The bar is
      // shorter than its slot so the popped-out circle has clear room above it.
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          12 + MediaQuery.of(context).padding.bottom,
        ),
        child: SizedBox(
          height: 92,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The floating rounded bar, pinned to the bottom of the slot.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                ),
              ),
              // The 5 tabs, evenly spread across the bar.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 72,
                child: Row(
                  children: [
                    for (var i = 0; i < _destinations.length; i++)
                      Expanded(
                        child: _NavItem(
                          data: _destinations[i],
                          selected: _index == i,
                          onTap: () => setState(() => _index = i),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One destination in the custom bottom bar.
class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavDestination(this.icon, this.selectedIcon, this.label);
}

/// Fixed left-to-right order of the tabs. Mirrors [_RootShellState._tabs];
/// Today sits in the center.
const _destinations = <_NavDestination>[
  _NavDestination(Icons.groups_outlined, Icons.groups, 'Community'),
  _NavDestination(
      Icons.fitness_center_outlined, Icons.fitness_center, 'Exercise'),
  _NavDestination(Icons.today_outlined, Icons.today, 'Today'),
  _NavDestination(Icons.history_outlined, Icons.history, 'History'),
  _NavDestination(Icons.person_outline, Icons.person, 'Profile'),
];

/// A single tab. The selected one lifts into a raised coral circle that pops
/// above the bar (à la example.png); the rest show a muted icon + small label.
class _NavItem extends StatelessWidget {
  final _NavDestination data;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.ink.withValues(alpha: 0.55);
    return InkResponse(
      onTap: onTap,
      radius: 40,
      child: SizedBox(
        height: 72,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Label pinned to the bottom so selected and unselected labels
            // always line up, whichever tab is active.
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? context.accent : muted,
                  ),
                ),
              ),
            ),
            // Up top: a muted icon, or — when selected — a raised coral circle
            // that pops above the bar.
            Align(
              alignment: Alignment.topCenter,
              child: selected
                  ? Transform.translate(
                      offset: const Offset(0, -18),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: context.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.accent.withValues(alpha: 0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(data.selectedIcon,
                            color: Colors.white, size: 26),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Icon(data.icon, color: muted, size: 24),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
