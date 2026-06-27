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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Capture service before async gap to avoid stale context
    final firestore = context.read<FirestoreService>();

    setState(() => _isSaving = true);
    try {
      final defaultColor = widget.type == 'Expense' ? '#E57373' : '#81C784';
      const defaultIcon = 'category';

      await firestore.createCategory({
        'name': _nameController.text.trim(),
        'type': widget.type,
        'icon': defaultIcon,
        'color': defaultColor,
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
    final isExpense = widget.type == 'Expense';
    final primaryColor = isExpense
        ? const Color(0xFFE57373)
        : const Color(0xFF81C784);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.translate('title_add_category'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
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
                      // Fix: withOpacity() is deprecated, use withValues()
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: primaryColor, width: 2),
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
              ElevatedButton(
                onPressed: _isSaving ? null : _saveCategory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
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
