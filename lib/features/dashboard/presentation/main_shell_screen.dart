import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../documents/presentation/documents_and_schedules_screen.dart';
import '../../family/presentation/family_and_profile_screen.dart';
import '../../health_records/presentation/health_monitor_screen.dart';
import 'home_dashboard_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeDashboardScreen(onNavigateTab: _selectTab),
          const HealthMonitorScreen(),
          const DocumentsAndSchedulesScreen(),
          const FamilyAndProfileScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          onPressed: () => context.push('/record/add'),
          tooltip: 'Catat Pemeriksaan',
          shape: const CircleBorder(),
          backgroundColor: AppColors.secondaryGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          child: const Icon(Icons.add_rounded, size: 34),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        elevation: 8,
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBarItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Beranda',
              selected: _currentIndex == 0,
              onTap: () => _selectTab(0),
            ),
            _NavBarItem(
              icon: Icons.show_chart_outlined,
              activeIcon: Icons.show_chart_rounded,
              label: 'Grafik',
              selected: _currentIndex == 1,
              onTap: () => _selectTab(1),
            ),
            const SizedBox(width: 56),
            _NavBarItem(
              icon: Icons.folder_copy_outlined,
              activeIcon: Icons.folder_copy_rounded,
              label: 'Dokumen',
              selected: _currentIndex == 2,
              onTap: () => _selectTab(2),
            ),
            _NavBarItem(
              icon: Icons.groups_outlined,
              activeIcon: Icons.groups_rounded,
              label: 'Keluarga',
              selected: _currentIndex == 3,
              onTap: () => _selectTab(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
