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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<FirestoreService>().getCategories(),
      builder: (context, snapshot) {
        final currentCategories = snapshot.data ?? categories;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final typeCategories = currentCategories
                .where((c) => c['type'] == activeType)
                .toList();

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Category',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
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
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: typeCategories.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No categories found. Click the pencil icon to add one!',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : SingleChildScrollView(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = (constraints.maxWidth - 10) / 2;
                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: typeCategories.map((cat) {
                                final isSelected =
                                    selectedCategoryId == cat['id'].toString();
                                return GestureDetector(
                                  onTap: () {
                                    onCategorySelected(cat['id'].toString());
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    width: itemWidth,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? activeColor.withOpacity(0.2)
                                                : Colors.white)
                                          : (Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? const Color(0xFF2C2C2C)
                                                : Colors.white),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isSelected
                                            ? activeColor
                                            : (Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF3C3C3C)
                                                  : const Color(0xFFEFEFEF)),
                                        width: isSelected ? 2.0 : 1.0,
                                      ),
                                      boxShadow: [
                                        if (isSelected)
                                          BoxShadow(
                                            color: activeColor.withOpacity(
                                              0.25,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 5),
                                          )
                                        else
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.06,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                      ],
                                    ),
                                    child: Text(
                                      context.getLocalizedCategory(
                                        cat['key']?.toString(),
                                        (cat['name'] == '👪 Family & Personal' ||
                                                cat['name'] == '👪 Family')
                                            ? '👪 Family'
                                            : cat['name'] ?? '',
                                      ),
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? activeColor
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
