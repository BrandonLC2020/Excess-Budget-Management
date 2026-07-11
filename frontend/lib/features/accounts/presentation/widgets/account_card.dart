import 'package:flutter/material.dart';
import '../../../../core/breakpoints.dart';
import '../../../../core/theme/refractive_glass.dart';
import '../../../../core/theme/thermal_glow.dart';
import '../../models/account.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final bool isSelected;
  final VoidCallback onTap;

  const AccountCard({
    super.key,
    required this.account,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ThermalGlow(
        onTap: onTap,
        child: RefractiveGlass(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: !context.isCompact && isSelected
                  ? Border.all(color: colorScheme.primary, width: 1.5)
                  : null,
            ),
            child: ListTile(
              title: Text(
                account.name,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                '\$${account.balance.toStringAsFixed(2)}',
                style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
