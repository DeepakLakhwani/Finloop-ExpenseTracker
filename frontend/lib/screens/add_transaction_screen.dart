import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/settings_provider.dart';
import '../providers/language_provider.dart';
import 'package:intl/intl.dart';
import 'add_transaction/widgets/category_selection_dialog.dart';
import 'add_transaction/widgets/account_selection_dialog.dart';
import 'add_transaction/widgets/fees_input_dialog.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../services/cloudinary_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final String initialType;
  final Map<String, dynamic>? initialTransaction;
  final String? prefilledAccountId;
  final String? prefilledToAccountId;

  const AddTransactionScreen({
    super.key,
    this.initialType = 'Expense',
    this.initialTransaction,
    this.prefilledAccountId,
    this.prefilledToAccountId,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  late String _type;
  String? _selectedAccountId;
  String? _toAccountId;
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  double _fees = 0.0;

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingData = true;
  bool _isSubmitting = false;
  bool _isStarred = false;
  String? _attachmentUrl;
  bool _isUploadingAttachment = false;
  bool _isPickingImage = false;

  bool get isEditing => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialTransaction?['type'] ?? widget.initialType;
    if (isEditing) {
      final tx = widget.initialTransaction!;
      _amountController.text = tx['amount']?.toString() ?? '';
      _notesController.text = tx['notes'] ?? '';
      _descriptionController.text = tx['description'] ?? '';
      _selectedAccountId =
          tx['account_id']?.toString() ?? tx['accountId']?.toString();
      _toAccountId =
          tx['to_account_id']?.toString() ?? tx['toAccountId']?.toString();
      _selectedCategoryId =
          tx['category_id']?.toString() ?? tx['categoryId']?.toString();
      _fees = double.tryParse(tx['fees']?.toString() ?? '0.0') ?? 0.0;

      _isStarred = tx['is_starred'] == true || tx['isStarred'] == true;
      _attachmentUrl = tx['attachment_url']?.toString();
      final dynamic dateVal = tx['date'];
      if (dateVal is Timestamp) {
        _selectedDate = dateVal.toDate();
      } else if (dateVal is String) {
        _selectedDate = DateTime.tryParse(dateVal) ?? DateTime.now();
      }
    } else {
      if (widget.prefilledAccountId != null) {
        _selectedAccountId = widget.prefilledAccountId;
      }
      if (widget.prefilledToAccountId != null) {
        _toAccountId = widget.prefilledToAccountId;
      }
    }
    _fetchData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _descriptionController.dispose();
    _noteFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoadingData = true);
    try {
      final firestore = context.read<FirestoreService>();
      // FIX: Wrap .first in try/catch; a stream error or empty completion would
      // previously crash silently. Timeout added to avoid hanging indefinitely.
      final results = await Future.wait([
        firestore.getAccounts().first,
        firestore.getCategories().first,
      ]).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      setState(() {
        _accounts = List<Map<String, dynamic>>.from(results[0]);
        _categories = List<Map<String, dynamic>>.from(results[1]);
        _isLoadingData = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.translate('error_load_data')}: $e'),
          ),
        );
      }
    }
  }

  // FIX: Simplified to if/else if chain
  Color _getActiveColor() {
    if (_type == 'Income') return const Color(0xFF42A5F5);
    if (_type == 'Expense') return const Color(0xFFE57373);
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF212121);
  }

  Color _getButtonTextColor() {
    if (_type == 'Transfer' &&
        Theme.of(context).brightness == Brightness.dark) {
      return Colors.black;
    }
    return Colors.white;
  }

  Future<bool> _saveTransaction() async {
    // FIX: Guard against null form state
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedAccountId == null) {
      _showSnackBar(context.translate('err_select_account'));
      return false;
    }

    if (_type != 'Transfer' && _selectedCategoryId == null) {
      _showSnackBar(context.translate('err_select_category'));
      return false;
    }

    // FIX: Validate transfer-specific fields
    if (_type == 'Transfer') {
      if (_toAccountId == null) {
        _showSnackBar(context.translate('err_select_dest_account'));
        return false;
      }
      if (_selectedAccountId == _toAccountId) {
        _showSnackBar(context.translate('err_accounts_same'));
        return false;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      final firestore = context.read<FirestoreService>();

      // FIX: Use tryParse with fallback instead of parse (avoids FormatException crash)
      final amount = double.tryParse(_amountController.text) ?? 0.0;

      // FIX: Use safe lookup helpers instead of firstWhere without orElse
      String categoryName = 'Unknown';
      String? categoryKey;
      if (_type == 'Transfer') {
        categoryName = context.translate('cat_transfer');
        categoryKey = 'cat_transfer';
      } else {
        final catMatch = _findById(_categories, _selectedCategoryId);
        if (catMatch != null) {
          categoryName = catMatch['name']?.toString() ?? 'Unknown';
          categoryKey = catMatch['key']?.toString();
        }
      }

      String accountName = 'Unknown';
      final accMatch = _findById(_accounts, _selectedAccountId);
      if (accMatch != null) {
        accountName = accMatch['name']?.toString() ?? 'Unknown';
      }

      String? toAccountName;
      if (_type == 'Transfer' && _toAccountId != null) {
        final toAccMatch = _findById(_accounts, _toAccountId);
        if (toAccMatch != null) {
          toAccountName = toAccMatch['name']?.toString();
        }
      }

      final txData = {
        'account_id': _selectedAccountId,
        'to_account_id': _type == 'Transfer' ? _toAccountId : null,
        'category_id': _selectedCategoryId,
        'category_name': categoryName,
        'category_key': categoryKey,
        'account_name': accountName,
        'to_account_name': toAccountName,
        'amount': amount,
        'type': _type,
        'date': Timestamp.fromDate(_selectedDate),
        'notes': _notesController.text.trim(),
        'description': _descriptionController.text.trim(),
        'fees': _type == 'Transfer' ? _fees : 0.0,
        'is_starred': _isStarred,
        'attachment_url': _attachmentUrl,
      };

      if (isEditing) {
        await firestore.updateTransaction(
          widget.initialTransaction!['id'],
          txData,
          widget.initialTransaction!,
        );
      } else {
        await firestore.createTransaction(txData);
      }
      return true;
    } catch (e) {
      if (mounted) _showSnackBar('${context.translate('error_save_tx')}: $e');
      return false;
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // FIX: Safe lookup helper — replaces bare firstWhere which throws StateError
  Map<String, dynamic>? _findById(List<dynamic> list, String? id) {
    if (id == null) return null;
    try {
      return list.firstWhere((item) => item['id'].toString() == id)
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitAndClose() async {
    final success = await _saveTransaction();
    if (success && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showCategorySelectionDialog({bool autoNext = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CategorySelectionDialog(
          categories: _categories,
          activeType: _type,
          selectedCategoryId: _selectedCategoryId,
          activeColor: _getActiveColor(),
          onCategorySelected: (id) {
            setState(() => _selectedCategoryId = id);
            if (autoNext) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  _showAccountSelectionDialog(
                    isToAccount: false,
                    autoNext: true,
                  );
                }
              });
            }
          },
          onCategoriesChanged: () async {
            await _fetchData();
          },
        );
      },
    );
  }

  void _showAccountSelectionDialog({
    required bool isToAccount,
    bool autoNext = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AccountSelectionDialog(
          accounts: _accounts,
          isToAccount: isToAccount,
          activeColor: _getActiveColor(),
          selectedAccountId: isToAccount ? _toAccountId : _selectedAccountId,
          onAccountSelected: (id) {
            setState(() {
              if (isToAccount) {
                _toAccountId = id;
              } else {
                _selectedAccountId = id;
              }
            });
            if (autoNext) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  if (_type == 'Transfer' && !isToAccount) {
                    _showAccountSelectionDialog(
                      isToAccount: true,
                      autoNext: true,
                    );
                  } else {
                    _noteFocusNode.requestFocus();
                  }
                }
              });
            }
          },
        );
      },
    );
  }

  void _showFeesInputDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return FeesInputDialog(
          initialFees: _fees,
          onSave: (fees) {
            setState(() => _fees = fees);
          },
        );
      },
    );
  }

  void _showAmountKeypad() {
    FocusScope.of(context).unfocus();
    final currency = context.read<SettingsProvider>().currency;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            
            String input = _amountController.text;
            if (input == '0.00' || input == '0' || input == '0.0') {
              input = '';
            }
            
            void updateInput(String value) {
              setSheetState(() {
                if (value == '.') {
                  if (input.isEmpty) {
                    input = '0.';
                  } else if (!input.contains('.')) {
                    input += '.';
                  }
                } else if (value == 'backspace') {
                  if (input.isNotEmpty) {
                    input = input.substring(0, input.length - 1);
                  }
                } else if (value == 'clear') {
                  input = '';
                } else {
                  if (input.contains('.')) {
                    final parts = input.split('.');
                    if (parts.length > 1 && parts[1].length >= 2) {
                      return;
                    }
                  }
                  if (input.length < 10) {
                    input += value;
                  }
                }
                _amountController.text = input;
              });
            }

            Widget buildKey(String label, {IconData? icon, String? customValue}) {
              final value = customValue ?? label;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                  child: Material(
                    color: isDark 
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3) 
                        : theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => updateInput(value),
                      child: Container(
                        height: 54,
                        alignment: Alignment.center,
                        child: icon != null
                            ? Icon(icon, color: theme.colorScheme.onSurface, size: 22)
                            : Text(
                                label,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark 
                          ? theme.colorScheme.surfaceContainerLow 
                          : theme.colorScheme.onSurface.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          currency,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _getActiveColor().withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            input.isEmpty ? '0.00' : input,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: input.isEmpty
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                                  : _getActiveColor(),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      buildKey('1'),
                      buildKey('2'),
                      buildKey('3'),
                    ],
                  ),
                  Row(
                    children: [
                      buildKey('4'),
                      buildKey('5'),
                      buildKey('6'),
                    ],
                  ),
                  Row(
                    children: [
                      buildKey('7'),
                      buildKey('8'),
                      buildKey('9'),
                    ],
                  ),
                  Row(
                    children: [
                      buildKey('.', customValue: '.'),
                      buildKey('0'),
                      buildKey('', icon: Icons.backspace_outlined, customValue: 'backspace'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => updateInput('clear'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              context.translate('clear'),
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              final parsed = double.tryParse(input);
                              if (parsed != null && parsed > 0) {
                                _amountController.text = input;
                                Navigator.pop(context);
                                
                                if (_type != 'Transfer') {
                                  _showCategorySelectionDialog(autoNext: true);
                                } else {
                                  _showAccountSelectionDialog(
                                    isToAccount: false,
                                    autoNext: true,
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(context.translate('err_invalid_amount')),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getActiveColor(),
                              foregroundColor: _getButtonTextColor(),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTransaction() async {
    // FIX: Block delete while another operation is in progress
    if (_isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.translate('delete_tx_title')),
          content: Text(context.translate('delete_tx_confirm')),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.translate('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.translate('delete'),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      setState(() => _isSubmitting = true);
      try {
        final firestore = context.read<FirestoreService>();
        await firestore.deleteTransaction(widget.initialTransaction!);
        if (mounted) {
          _showSnackBar(context.translate('settings_saved'));
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) _showSnackBar('Error deleting transaction: $e');
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _pickAndUploadAttachment() async {
    final picker = ImagePicker();

    // Show bottom sheet to choose source
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final double bottomPadding = MediaQuery.of(context).padding.bottom;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.translate('header_attachment'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                  _buildSourceOption(
                    icon: Icons.photo_library_outlined,
                    label: 'Gallery',
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (source == null) return;
    if (_isPickingImage) return;

    setState(() => _isPickingImage = true);

    try {
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      setState(() => _isPickingImage = false);
      if (image == null) return;

      setState(() => _isUploadingAttachment = true);

      final cloudinary = CloudinaryService();
      final String? uploadedUrl = await cloudinary.uploadImage(image.path);

      if (uploadedUrl != null) {
        setState(() {
          _attachmentUrl = uploadedUrl;
          _isUploadingAttachment = false;
        });
        _showSnackBar('Attachment uploaded successfully!');
      } else {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    } on PlatformException catch (e) {
      setState(() {
        _isPickingImage = false;
        _isUploadingAttachment = false;
      });
      debugPrint('PlatformException picking image: $e');
      if (e.code == 'photo_access_denied' || e.code == 'camera_access_denied') {
        _showSnackBar(
          'Access denied. Please grant library/camera permissions in your device settings.',
        );
      } else if (e.code == 'already_active') {
        _showSnackBar('Image picker is already active.');
      } else {
        _showSnackBar('Error: ${e.message} (${e.code})');
      }
    } catch (e) {
      setState(() {
        _isPickingImage = false;
        _isUploadingAttachment = false;
      });
      _showSnackBar('Failed to upload attachment: $e');
    }
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _viewFullscreenImage(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<SettingsProvider>().currency;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.translate(_type.toLowerCase()),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: false,
        actions: [
          if (isEditing)
            // FIX: Disable delete button while submitting
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _isSubmitting ? null : _deleteTransaction,
            ),
          IconButton(
            icon: Icon(
              _isStarred ? Icons.star : Icons.star_border_outlined,
              color: _isStarred
                  ? Colors.amber
                  : Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              setState(() {
                _isStarred = !_isStarred;
              });
            },
          ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTypeToggle(),
                    const SizedBox(height: 24),

                    _buildFormRow(
                      label: context.translate('label_date'),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _pickDate,
                            child: Text(
                              DateFormat(
                                'dd/MM/yyyy (EEE)',
                              ).format(_selectedDate),
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _pickTime,
                            child: Text(
                              DateFormat('h:mm a').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildFormRow(
                      label: context.translate('label_amount'),
                      child: Row(
                        children: [
                          Text(
                            currency,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _amountController,
                              readOnly: true,
                              onTap: _showAmountKeypad,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              validator: (val) {
                                final parsed = val == null
                                    ? null
                                    : double.tryParse(val);
                                if (parsed == null || parsed <= 0) {
                                  return context.translate(
                                    'err_invalid_amount',
                                  );
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      trailing: _type == 'Transfer'
                          ? InkWell(
                              onTap: _showFeesInputDialog,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        // FIX: withOpacity deprecated; use withValues
                                        .withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _fees > 0
                                      ? '${context.translate('label_fees')}: $currency${_fees.toStringAsFixed(0)}'
                                      : context.translate('label_fees'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            )
                          : null,
                    ),

                    if (_type != 'Transfer') ...[
                      _buildFormRow(
                        label: context.translate('label_category'),
                        child: GestureDetector(
                          onTap: _showCategorySelectionDialog,
                          child: Text(
                            (() {
                              final cat = _findById(
                                _categories,
                                _selectedCategoryId,
                              );
                              if (cat == null)
                                return context.translate(
                                  'select_category_hint',
                                );
                              return context.getLocalizedCategory(
                                cat['key']?.toString(),
                                cat['name']?.toString() ?? 'Unknown',
                              );
                            })(),
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedCategoryId != null
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                      _buildFormRow(
                        label: context.translate('label_account'),
                        child: GestureDetector(
                          onTap: () =>
                              _showAccountSelectionDialog(isToAccount: false),
                          child: Text(
                            _findById(_accounts, _selectedAccountId)?['name'] ??
                                context.translate('select_account_hint'),
                            style: TextStyle(
                              fontSize: 14,
                              color: _selectedAccountId != null
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _buildFormRow(
                                  label: context.translate('label_from'),
                                  child: GestureDetector(
                                    onTap: () => _showAccountSelectionDialog(
                                      isToAccount: false,
                                    ),
                                    child: Text(
                                      _findById(
                                            _accounts,
                                            _selectedAccountId,
                                          )?['name'] ??
                                          context.translate(
                                            'select_account_hint',
                                          ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _selectedAccountId != null
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                ),
                                _buildFormRow(
                                  label: context.translate('label_to'),
                                  child: GestureDetector(
                                    onTap: () => _showAccountSelectionDialog(
                                      isToAccount: true,
                                    ),
                                    child: Text(
                                      _findById(
                                            _accounts,
                                            _toAccountId,
                                          )?['name'] ??
                                          context.translate(
                                            'select_account_hint',
                                          ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _toAccountId != null
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.4),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.swap_vert,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            onPressed: () {
                              setState(() {
                                final temp = _selectedAccountId;
                                _selectedAccountId = _toAccountId;
                                _toAccountId = temp;
                              });
                            },
                          ),
                        ],
                      ),
                    ],

                    _buildFormRow(
                      label: context.translate('label_note'),
                      child: TextFormField(
                        controller: _notesController,
                        focusNode: _noteFocusNode,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          _descriptionFocusNode.requestFocus();
                        },
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: context.translate('note_hint'),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.only(top: 24),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _descriptionController,
                              focusNode: _descriptionFocusNode,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submitAndClose(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: context.translate(
                                  'label_description',
                                ),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _attachmentUrl != null
                                  ? Icons.camera_alt
                                  : Icons.camera_alt_outlined,
                              color: _attachmentUrl != null
                                  ? AppColors.primary
                                  : Theme.of(context).colorScheme.onSurface
                                        .withValues(alpha: 0.5),
                            ),
                            onPressed: _isUploadingAttachment
                                ? null
                                : _pickAndUploadAttachment,
                          ),
                        ],
                      ),
                    ),

                    // Attachment Preview / Uploader UI
                    if (_isUploadingAttachment) ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Uploading attachment...',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else if (_attachmentUrl != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.08),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    _viewFullscreenImage(_attachmentUrl!),
                                child: Image.network(
                                  _attachmentUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 40,
                                      ),
                                    );
                                  },
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        );
                                      },
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _attachmentUrl = null;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitAndClose,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getActiveColor(),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: _getButtonTextColor(),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isEditing
                                    ? context.translate('btn_update')
                                    : context.translate('btn_save'),
                                style: TextStyle(
                                  color: _getButtonTextColor(),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          _buildToggleItem('Income'),
          const SizedBox(width: 4),
          _buildToggleItem('Expense'),
          const SizedBox(width: 4),
          _buildToggleItem('Transfer'),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label) {
    final bool isSelected = _type == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _type = label;
          _selectedCategoryId = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white)
                : (Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2C)
                      : const Color(0xFFF1F1F1)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? _getActiveColor() : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Center(
            child: Text(
              context.translate(label.toLowerCase()),
              style: TextStyle(
                color: isSelected
                    ? _getActiveColor()
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormRow({
    required String label,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: child),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2000),
      // FIX: Restrict to today — finance apps rarely need future-dated entries.
      // Change to now.add(Duration(days: 365)) if future dates are intentional.
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _getActiveColor(),
              onPrimary: _getButtonTextColor(),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        _selectedDate.hour,
        _selectedDate.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
      // FIX: Allow both dial and input modes for accessibility
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: _getActiveColor(),
              onPrimary: _getButtonTextColor(),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            timePickerTheme: TimePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              hourMinuteTextStyle: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              dayPeriodTextStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              helpTextStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              dialTextStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              hourMinuteColor: _getActiveColor().withValues(alpha: 0.12),
              hourMinuteTextColor: _getActiveColor(),
              dayPeriodColor: _getActiveColor().withValues(alpha: 0.12),
              dayPeriodTextColor: _getActiveColor(),
              dialHandColor: _getActiveColor(),
              dialBackgroundColor: Theme.of(context).colorScheme.surface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _getActiveColor(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time == null || !mounted) return;
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        time.hour,
        time.minute,
      );
    });
  }
}
