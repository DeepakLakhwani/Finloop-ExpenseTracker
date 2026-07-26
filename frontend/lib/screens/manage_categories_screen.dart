import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../providers/language_provider.dart';
import 'add_category_screen.dart';

class ManageCategoriesScreen extends StatelessWidget {
  final String type; // 'Income' or 'Expense'

  const ManageCategoriesScreen({super.key, required this.type});

  Color _parseColor(String? hex) {
    if (hex == null || !hex.startsWith('#')) return const Color(0xFFE57373);
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return const Color(0xFFE57373);
    }
  }

  IconData _getIconData(String? code) {
    switch (code) {
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
      default:
        return Icons.category_outlined;
    }
  }

  void _showSimpleDeleteCategoryDialog(
    BuildContext context,
    Map<String, dynamic> cat,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.translate('title_delete_category'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context
              .translate('delete_category_confirm')
              .replaceAll(
                '{category}',
                context.getLocalizedCategory(
                  cat['key']?.toString(),
                  cat['name'] ?? '',
                ),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.translate('cancel'),
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await context.read<FirestoreService>().deleteCategory(cat['id']);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              context.translate('delete'),
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.translate('title_manage_categories')} (${context.translate(type.toLowerCase())})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 28),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddCategoryScreen(type: type),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: firestore.getCategories(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final categories = snapshot.data!
              .where((c) => c['type'] == type)
              .toList();

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.translate('err_no_categories'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.translate('hint_add_category'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            );
          }

          final bottomPad = MediaQuery.of(context).padding.bottom + 16;
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(0, 10, 0, bottomPad),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final color = _parseColor(cat['color']);
              final iconData = _getIconData(cat['icon']);
              final name = context.getLocalizedCategory(
                cat['key']?.toString(),
                cat['name'] ?? '',
              );

              return Card(
                margin: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(iconData, color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddCategoryScreen(
                                type: type,
                                categoryToEdit: cat,
                              ),
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 22,
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        onPressed: () =>
                            _showSimpleDeleteCategoryDialog(context, cat),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 22,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
