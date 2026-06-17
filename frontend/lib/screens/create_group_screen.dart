import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../main.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _emailController = TextEditingController();
  final _manualMemberController = TextEditingController();

  String? _selectedIconUrl;
  final List<Map<String, String>> _defaultIcons = [
    {
      'name': 'Trip',
      'url':
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=150&q=80',
    },
    {
      'name': 'Home',
      'url':
          'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=150&q=80',
    },
    {
      'name': 'Office',
      'url':
          'https://images.unsplash.com/photo-1497366216548-37526070297c?w=150&q=80',
    },
    {
      'name': 'Food',
      'url':
          'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=150&q=80',
    },
    {
      'name': 'Games',
      'url':
          'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=150&q=80',
    },
  ];

  final List<Map<String, dynamic>> _initialMembers = [];
  bool _isSearchingUser = false;

  // FIX 1: Guard against empty icons list to avoid crash in initState
  @override
  void initState() {
    super.initState();
    if (_defaultIcons.isNotEmpty) {
      _selectedIconUrl = _defaultIcons[0]['url'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _emailController.dispose();
    _manualMemberController.dispose();
    super.dispose();
  }

  // FIX 2: Basic email format validation helper
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _searchAndAddUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    // FIX 3: Validate email format before making a network call
    if (!_isValidEmail(email)) {
      showTopNotification('Please enter a valid email address.', isError: true);
      return;
    }

    // FIX 4: Dismiss keyboard before async work
    FocusScope.of(context).unfocus();

    setState(() => _isSearchingUser = true);
    try {
      final results = await context.read<GroupProvider>().searchUsersByEmail(
        email,
      );

      // FIX 5: Check mounted after every async gap before touching context or setState
      if (!mounted) return;

      if (results.isEmpty) {
        showTopNotification(
          'No registered user found with that email. You can add them as a manual member instead!',
          isError: true,
        );
      } else {
        final user = results.first;
        final uid = user['uid'] as String;
        final name = (user['displayName'] as String?)?.isNotEmpty == true
            ? user['displayName'] as String
            : (user['email'] as String? ?? email);

        if (_initialMembers.any((m) => m['uid'] == uid)) {
          showTopNotification('User is already added!', isError: true);
          return;
        }

        setState(() {
          _initialMembers.add({
            'name': name,
            'email': email,
            'uid': uid,
            'isAppUser': true,
          });
          _emailController.clear();
        });
        showTopNotification('App user "$name" added to group!');
      }
    } catch (e) {
      // FIX 6: Guard mounted before showTopNotification in catch block
      if (!mounted) return;
      showTopNotification('Error searching user: $e', isError: true);
    } finally {
      // FIX 7: Guard mounted before calling setState in finally to prevent memory leaks
      if (mounted) {
        setState(() => _isSearchingUser = false);
      }
    }
  }

  void _addManualMember() {
    final name = _manualMemberController.text.trim();
    if (name.isEmpty) return;

    // FIX 8: Prevent duplicate manual member names (case-insensitive)
    final alreadyExists = _initialMembers.any(
      (m) => (m['name'] as String).toLowerCase() == name.toLowerCase(),
    );
    if (alreadyExists) {
      showTopNotification('"$name" is already in the list!', isError: true);
      return;
    }

    // FIX 9: Dismiss keyboard after adding
    FocusScope.of(context).unfocus();

    setState(() {
      _initialMembers.add({
        'name': name,
        'email': null,
        'uid': null,
        'isAppUser': false,
      });
      _manualMemberController.clear();
    });
    showTopNotification('Manual member "$name" added!');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // FIX 10: Dismiss keyboard on submit
    FocusScope.of(context).unfocus();

    final provider = context.read<GroupProvider>();
    final groupId = await provider.createGroup(
      _nameController.text.trim(),
      _descController.text.trim(),
      _selectedIconUrl,
    );

    // FIX 11: Check mounted after createGroup async call
    if (!mounted) return;

    if (groupId != null) {
      for (final member in _initialMembers) {
        await provider.addMember(
          groupId,
          name: member['name'],
          email: member['email'],
          uid: member['uid'],
        );
        // FIX 12: Check mounted inside the loop — widget could be gone mid-iteration
        if (!mounted) return;
      }

      showTopNotification('Group created successfully!');
      Navigator.pop(context);
    } else {
      showTopNotification(
        'Failed to create group. Please try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupProvider = context.watch<GroupProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create New Group',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: groupProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group Icon Picker
                    const Text(
                      'Group Avatar / Theme',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _defaultIcons.length,
                        itemBuilder: (context, index) {
                          final item = _defaultIcons[index];
                          final isSelected = _selectedIconUrl == item['url'];
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selectedIconUrl = item['url']),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundImage: NetworkImage(item['url']!),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Inputs
                    CustomTextField(
                      controller: _nameController,
                      hintText: 'e.g. Goa Trip, Flatmates',
                      label: 'Group Name',
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Enter group name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _descController,
                      hintText: 'e.g. Shared expenses for Goa trip May 2026',
                      label: 'Description',
                    ),
                    const SizedBox(height: 28),

                    // Add Members Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        // FIX 13: Replace deprecated withOpacity with withValues(alpha:)
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.person_add_alt_1_rounded,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Add Members Now',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add friends as manual members (by name) or search existing users (by email)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Search App User by Email
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(fontSize: 14),
                                  // FIX 14: Allow submitting via keyboard action
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _searchAndAddUser(),
                                  decoration: InputDecoration(
                                    hintText: 'Search user by email...',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _isSearchingUser
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: _searchAndAddUser,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        minimumSize: const Size(0, 40),
                                      ),
                                      child: const Text(
                                        'Add User',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Add Manual Member by Name
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _manualMemberController,
                                  style: const TextStyle(fontSize: 14),
                                  // FIX 15: Allow submitting via keyboard action
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _addManualMember(),
                                  decoration: InputDecoration(
                                    hintText: 'Or enter manual member name...',
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _addManualMember,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: AppColors.primary,
                                  elevation: 0,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  minimumSize: const Size(0, 40),
                                ),
                                child: const Text(
                                  'Add Manual',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Added Members List
                    // FIX 16: Use Column instead of shrinkWrap ListView for better performance
                    // inside a SingleChildScrollView
                    if (_initialMembers.isNotEmpty) ...[
                      const Text(
                        'Added Members List',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Column(
                        children: List.generate(_initialMembers.length, (
                          index,
                        ) {
                          final member = _initialMembers[index];
                          final isAppUser =
                              member['isAppUser'] as bool? ?? false;

                          // FIX 17: Safe subtitle — avoid null crash on missing 'email' key
                          final emailText = member['email'] as String?;

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: isAppUser
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : Colors.black12,
                                child: Icon(
                                  isAppUser
                                      ? Icons.verified_rounded
                                      : Icons.person_outline,
                                  size: 16,
                                  color: isAppUser
                                      ? AppColors.primary
                                      : Colors.black54,
                                ),
                              ),
                              title: Text(
                                member['name'] as String? ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                emailText != null && emailText.isNotEmpty
                                    ? emailText
                                    : 'Manual Member',
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _initialMembers.removeAt(index),
                                  );
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                    ],

                    CustomButton(text: 'Create Group', onPressed: _submit),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
