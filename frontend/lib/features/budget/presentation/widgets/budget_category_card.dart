import 'package:flutter/material.dart';
import '../../../../core/theme/llc_theme.dart';
import '../../../../core/theme/refractive_glass.dart';
import '../../../../core/theme/thermal_glow.dart';
import '../../models/budget_category.dart';

class BudgetCategoryCard extends StatelessWidget {
  final BudgetCategory category;
  final double percent;
  final VoidCallback onTap;

  const BudgetCategoryCard({
    super.key,
    required this.category,
    required this.percent,
    required this.onTap,
  });

  Color _parseColor(String? hex) {
    if (hex == null) return LLCColors.steelGray;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return LLCColors.steelGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _parseColor(category.colorHex);
    final categoryIcon = category.iconCode != null
        ? IconData(category.iconCode!, fontFamily: 'MaterialIcons')
        : Icons.category;
    final colorScheme = Theme.of(context).colorScheme;
    final isOverLimit = percent >= 1.0;

    return ThermalGlow(
      onTap: onTap,
      child: RefractiveGlass(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'category_icon_${category.id}',
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(categoryIcon, color: categoryColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isOverLimit)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  category.type == BudgetCategoryType.income
                                      ? Icons.arrow_upward
                                      : Icons.warning_amber_rounded,
                                  size: 14,
                                  color: category.type == BudgetCategoryType.income
                                      ? LLCColors.affirmMint
                                      : colorScheme.error,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                category.type == BudgetCategoryType.income
                                    ? 'Saved \$${category.spentAmount.toStringAsFixed(2)} of \$${category.limitAmount.toStringAsFixed(2)}'
                                    : 'Spent \$${category.spentAmount.toStringAsFixed(2)} of \$${category.limitAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: category.type == BudgetCategoryType.income
                      ? (isOverLimit ? LLCColors.affirmMint : categoryColor)
                      : (isOverLimit ? colorScheme.error : categoryColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
