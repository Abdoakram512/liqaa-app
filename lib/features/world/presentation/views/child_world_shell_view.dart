import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/dependency_injection/service_locator.dart';
import '../../data/child_world_repository.dart';
import '../cubits/child_world_cubit.dart';
import '../widgets/yasser_world_nav_bar.dart';
import 'adventure_book_view.dart';
import 'mini_games_hub_view.dart';
import 'my_personal_home_view.dart';
import 'world_map_view.dart';

/// Main 4-destination living world container replacing isolated menu screens:
/// - `عالمي` (My Personal Home)
/// - `مغامرتي` (Interactive World Map)
/// - `ألعابي` (8 Mini-Games Hub)
/// - `كنوزي` (My Adventure Book & Progress)
class ChildWorldShellView extends StatefulWidget {
  final int initialTabIndex;

  const ChildWorldShellView({super.key, this.initialTabIndex = 0});

  @override
  State<ChildWorldShellView> createState() => _ChildWorldShellViewState();
}

class _ChildWorldShellViewState extends State<ChildWorldShellView> {
  late int _selectedIndex;
  ChildWorldCubit? _ownedCubit;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex.clamp(0, 3);
    if (!sl.isRegistered<ChildWorldCubit>()) {
      // Safe fallback in isolated widget tests without full setupServiceLocator
      final prefs = sl.isRegistered<SharedPreferences>()
          ? sl<SharedPreferences>()
          : null;
      if (prefs != null) {
        _ownedCubit = ChildWorldCubit(ChildWorldRepository(prefs));
      }
    }
  }

  @override
  void dispose() {
    _ownedCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = sl.isRegistered<ChildWorldCubit>()
        ? sl<ChildWorldCubit>()
        : _ownedCubit;

    if (cubit == null) {
      return FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          _ownedCubit ??= ChildWorldCubit(ChildWorldRepository(snap.data!));
          return BlocProvider<ChildWorldCubit>.value(
            value: _ownedCubit!,
            child: _buildShell(context),
          );
        },
      );
    }

    return BlocProvider<ChildWorldCubit>.value(
      value: cubit,
      child: _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    return BlocBuilder<ChildWorldCubit, ChildWorldCubitState>(
      builder: (context, state) {
        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: [
              MyPersonalHomeView(
                onOpenMap: () => setState(() => _selectedIndex = 1),
                onOpenGames: () => setState(() => _selectedIndex = 2),
              ),
              const WorldMapView(),
              const MiniGamesHubView(),
              const AdventureBookView(),
            ],
          ),
          bottomNavigationBar: YasserWorldNavBar(
            selectedIndex: _selectedIndex,
            unseenTreasuresCount: state.worldState.unseenCollectibleIds.length,
            onSelected: (idx) {
              setState(() => _selectedIndex = idx);
              if (idx == 3) {
                context.read<ChildWorldCubit>().markCollectiblesSeen();
              }
            },
          ),
        );
      },
    );
  }
}
