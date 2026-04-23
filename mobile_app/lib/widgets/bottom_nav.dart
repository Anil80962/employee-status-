import 'package:flutter/material.dart';
import '../theme.dart';

class FluxNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const FluxNavBar({super.key, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.home_rounded, 'Home'),
      (Icons.assignment_rounded, 'Update'),
      (Icons.groups_rounded, 'Team'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE6EAF0))),
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = i == index;
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(items[i].$1,
                        color: selected ? AppColors.primary : AppColors.sub),
                    const SizedBox(height: 4),
                    Text(items[i].$2,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.primary
                                : AppColors.sub)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
