import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/ui/app_colors.dart';

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    super.key,
    required this.activeDestination,
    required this.onSelect,
  });
  final int activeDestination;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    const destinations = [
      (Icons.explore, 'Explorer'),
      (Icons.find_in_page, 'Search'),
      (Icons.filter_list, 'Filters'),
      (Icons.settings, 'Settings'),
    ];
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: destinations.indexed
            .map(
              (item) => Expanded(
                child: _NavigationItem(
                  icon: item.$2.$1,
                  label: item.$2.$2,
                  selected: item.$1 == activeDestination,
                  index: item.$1,
                  onTap: () => onSelect(item.$1),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.index,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final int index;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.secondaryText;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, key: Key('nav_icon_$index'), color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
