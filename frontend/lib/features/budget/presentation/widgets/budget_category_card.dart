import 'package:flutter/material.dart';
import '../../models/budget_category.dart';

class BudgetCategoryCard extends StatefulWidget {
  final BudgetCategory category;
  final double percent;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const BudgetCategoryCard({
    super.key,
    required this.category,
    required this.percent,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<BudgetCategoryCard> createState() => _BudgetCategoryCardState();
}

class _BudgetCategoryCardState extends State<BudgetCategoryCard> {
  bool _isHovered = false;

  Color _parseColor(String? hex) {
    if (hex == null) return Colors.grey;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryColor = _parseColor(widget.category.colorHex);
    final categoryIcon = widget.category.iconCode != null
        ? IconData(widget.category.iconCode!, fontFamily: 'MaterialIcons')
        : Icons.category;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.0),
              blurRadius: _isHovered ? 12 : 0,
              offset: Offset(0, _isHovered ? 6 : 0),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: _isHovered
                  ? categoryColor.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            hoverColor: categoryColor.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: 'category_icon_${widget.category.id}',
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
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
                              widget.category.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.category.type == BudgetCategoryType.income
                                  ? 'Saved \$${widget.category.spentAmount.toStringAsFixed(2)} of \$${widget.category.limitAmount.toStringAsFixed(2)}'
                                  : 'Spent \$${widget.category.spentAmount.toStringAsFixed(2)} of \$${widget.category.limitAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: widget.percent,
                      minHeight: 6,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      color: widget.category.type == BudgetCategoryType.income
                          ? (widget.percent >= 1.0
                                ? Colors.green
                                : categoryColor)
                          : (widget.percent >= 1.0
                                ? Theme.of(context).colorScheme.error
                                : categoryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
