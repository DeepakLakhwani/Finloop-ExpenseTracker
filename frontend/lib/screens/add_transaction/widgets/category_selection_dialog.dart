import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/firestore_service.dart';
import '../../../providers/language_provider.dart';
import '../../manage_categories_screen.dart';

class CategorySelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String activeType;
  final String? selectedCategoryId;
  final Color activeColor;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onCategoriesChanged;

  const CategorySelectionDialog({
    super.key,
    required this.categories,
    required this.activeType,
    required this.selectedCategoryId,
    required this.activeColor,
    required this.onCategorySelected,
    required this.onCategoriesChanged,
  });

  Color _parseColor(String? hex) {
    if (hex == null || !hex.startsWith('#')) return const Color(0xFFE57373);
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return const Color(0xFFE57373);
    }
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'work':
        return Icons.work_outline;
      case 'payments':
        return Icons.payments_outlined;
      case 'card_giftcard':
        return Icons.card_giftcard_outlined;
      case 'stars':
        return Icons.stars_outlined;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'directions_car':
        return Icons.directions_car_outlined;
      case 'shopping_bag':
        return Icons.shopping_bag_outlined;
      case 'movie':
        return Icons.movie_outlined;
      case 'medical_services':
        return Icons.medical_services_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'credit_card':
        return Icons.credit_card_outlined;
      case 'people':
        return Icons.people_outline;
      case 'flight':
        return Icons.flight_outlined;
      case 'pets':
        return Icons.pets_outlined;
      case 'sports_esports':
        return Icons.sports_esports_outlined;
      case 'fitness_center':
        return Icons.fitness_center_outlined;
      case 'local_cafe':
        return Icons.local_cafe_outlined;
      case 'build':
        return Icons.build_outlined;
      case 'swap_horiz':
        return Icons.swap_horiz;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double screenWidth = MediaQuery.of(context).size.width;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<FirestoreService>().getCategories(),
      builder: (context, snapshot) {
        final currentCategories = snapshot.data ?? categories;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final typeCategories = currentCategories
                .where((c) => c['type'] == activeType)
                .toList();

            final int crossAxisCount = screenWidth > 600 ? 3 : 2;
            final double childAspectRatio = screenWidth < 360
                ? 2.1
                : (screenWidth < 400 ? 2.4 : 2.8);

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.translate('select_category_hint'),
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined, 
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            tooltip: 'Manage Categories',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ManageCategoriesScreen(type: activeType),
                                ),
                              ).then((_) {
                                onCategoriesChanged();
                                setDialogState(() {});
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Content
                  Flexible(
                    child: typeCategories.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              'No categories found. Click the pencil icon to add one!',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : SingleChildScrollView(
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: childAspectRatio,
                              ),
                              itemCount: typeCategories.length,
                              itemBuilder: (context, index) {
                                final cat = typeCategories[index];
                                final isSelected =
                                    selectedCategoryId == cat['id'].toString();
                                final catColor = _parseColor(cat['color']);
                                final catIcon = _getCategoryIcon(cat['icon']);
                                
                                // Strip emojis from display name if they are in the database string
                                String displayName = context.getLocalizedCategory(
                                  cat['key']?.toString(),
                                  cat['name'] ?? '',
                                );
                                // Clean up any lingering emojis at the start of fallback name if it falls back
                                if (displayName.startsWith(RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]', unicode: true))) {
                                  displayName = displayName.replaceFirst(RegExp(r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]\s*', unicode: true), '');
                                }

                                return InkWell(
                                  onTap: () {
                                    onCategorySelected(cat['id'].toString());
                                    Navigator.pop(context);
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? catColor.withValues(alpha: 0.1)
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? catColor
                                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            catIcon,
                                            color: catColor,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: screenWidth < 360 ? 11 : 12,
                                              height: 1.1,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: catColor,
                                            size: 14,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
