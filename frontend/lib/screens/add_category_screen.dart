import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../providers/language_provider.dart';

class AddCategoryScreen extends StatefulWidget {
  final String type; // 'Income' or 'Expense'

  const AddCategoryScreen({super.key, required this.type});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late String _selectedColorHex;
  String _selectedIconCode = 'account_balance_wallet';

  final List<String> _colors = [
    '#E57373', // Coral Red
    '#F44336', // Red
    '#E91E63', // Pink
    '#9C27B0', // Purple
    '#673AB7', // Deep Purple
    '#3F51B5', // Indigo
    '#2196F3', // Blue
    '#00BCD4', // Cyan
    '#009688', // Teal
    '#4CAF50', // Green
    '#8BC34A', // Light Green
    '#FFC107', // Amber
    '#FF9800', // Orange
    '#FF5722', // Deep Orange
    '#795548', // Brown
    '#607D8B', // Blue Grey
  ];

  final List<Map<String, dynamic>> _icons = [
    {'code': 'account_balance_wallet', 'icon': Icons.account_balance_wallet_outlined},
    {'code': 'restaurant', 'icon': Icons.restaurant_outlined},
    {'code': 'shopping_bag', 'icon': Icons.shopping_bag_outlined},
    {'code': 'directions_car', 'icon': Icons.directions_car_outlined},
    {'code': 'home', 'icon': Icons.home_outlined},
    {'code': 'movie', 'icon': Icons.movie_outlined},
    {'code': 'medical_services', 'icon': Icons.medical_services_outlined},
    {'code': 'school', 'icon': Icons.school_outlined},
    {'code': 'work', 'icon': Icons.work_outline},
    {'code': 'payments', 'icon': Icons.payments_outlined},
    {'code': 'card_giftcard', 'icon': Icons.card_giftcard_outlined},
    {'code': 'stars', 'icon': Icons.stars_outlined},
    {'code': 'credit_card', 'icon': Icons.credit_card_outlined},
    {'code': 'people', 'icon': Icons.people_outline},
    {'code': 'flight', 'icon': Icons.flight_outlined},
    {'code': 'pets', 'icon': Icons.pets_outlined},
    {'code': 'sports_esports', 'icon': Icons.sports_esports_outlined},
    {'code': 'fitness_center', 'icon': Icons.fitness_center_outlined},
    {'code': 'local_cafe', 'icon': Icons.local_cafe_outlined},
    {'code': 'build', 'icon': Icons.build_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _selectedColorHex = widget.type == 'Expense' ? '#E57373' : '#4CAF50';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return const Color(0xFFE57373);
    }
  }

  Future<void> _saveCategory() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final firestore = context.read<FirestoreService>();

    setState(() => _isSaving = true);
    try {
      await firestore.createCategory({
        'name': _nameController.text.trim(),
        'type': widget.type,
        'icon': _selectedIconCode,
        'color': _selectedColorHex,
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${context.translate('err_save_category')}$e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _parseColor(_selectedColorHex);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.translate('title_add_category'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: false,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _saveCategory(),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.translate('err_category_name_empty');
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: context.translate('hint_category_name'),
                  filled: false,
                  fillColor: Colors.transparent,
                  border: const UnderlineInputBorder(),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: activeColor, width: 2),
                  ),
                  errorBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                  focusedErrorBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Color Label
              Text(
                context.translate('label_category_color'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              
              // Colors Row / Wrap
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colors.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final colorHex = _colors[index];
                    final color = _parseColor(colorHex);
                    final isSelected = _selectedColorHex == colorHex;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColorHex = colorHex;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: isSelected ? 2.5 : 0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Icon Label
              Text(
                context.translate('label_category_icon'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),

              // Icon Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: _icons.length,
                itemBuilder: (context, index) {
                  final iconItem = _icons[index];
                  final isSelected = _selectedIconCode == iconItem['code'];
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedIconCode = iconItem['code'];
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withValues(alpha: 0.12)
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? activeColor
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Icon(
                        iconItem['icon'],
                        color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 36),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        context.translate('btn_save'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
