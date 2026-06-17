import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_member.dart';
import '../providers/group_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_colors.dart';
import '../main.dart';

class GroupMembersScreen extends StatefulWidget {
  final String groupId;
  const GroupMembersScreen({super.key, required this.groupId});

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final _emailController = TextEditingController();
  final _manualNameController = TextEditingController();
  bool _isSearchingUser = false;

  @override
  void dispose() {
    _emailController.dispose();
    _manualNameController.dispose();
    super.dispose();
  }

  Future<void> _searchAndAddUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isSearchingUser = true);
    try {
      final provider = context.read<GroupProvider>();
      final results = await provider.searchUsersByEmail(email);
      
      if (results.isEmpty) {
        showTopNotification('No registered user found with that email. You can add them as a manual contact instead!', isError: true);
      } else {
        final user = results.first;
        final uid = user['uid'] as String;
        final name = (user['displayName'] as String?)?.isNotEmpty == true
            ? user['displayName'] as String
            : (user['email'] as String);

        // Check if already a member in the group
        final members = await provider.getGroupMembersStream(widget.groupId).first;
        if (members.any((m) => m.id == uid)) {
          showTopNotification('User is already a member of this group!', isError: true);
          return;
        }

        final success = await provider.addMember(
          widget.groupId,
          name: name,
          email: email,
          uid: uid,
        );

        if (success) {
          _emailController.clear();
          showTopNotification('Registered user "$name" added successfully!');
        } else {
          showTopNotification('Failed to add member. Please try again.', isError: true);
        }
      }
    } catch (e) {
      showTopNotification('Error adding member: $e', isError: true);
    } finally {
      setState(() => _isSearchingUser = false);
    }
  }

  Future<void> _addManualMember() async {
    final name = _manualNameController.text.trim();
    if (name.isEmpty) return;

    try {
      final provider = context.read<GroupProvider>();
      final success = await provider.addMember(
        widget.groupId,
        name: name,
        email: null,
        uid: null,
      );

      if (success) {
        _manualNameController.clear();
        showTopNotification('Manual contact "$name" added successfully!');
      } else {
        showTopNotification('Failed to add member. Please try again.', isError: true);
      }
    } catch (e) {
      showTopNotification('Error adding member: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = context.watch<SettingsProvider>().currency;
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Members', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<GroupMember>>(
        stream: groupProvider.getGroupMembersStream(widget.groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data ?? [];

          return Column(
            children: [
              // Members List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final m = members[index];
                    final isMe = m.id == myUid;
                    final mName = isMe ? '${m.name} (You)' : m.name;
                    final bal = m.balance;

                    Color balanceColor = Colors.grey;
                    String balanceText = 'Settled up';
                    if (bal > 0.01) {
                      balanceColor = AppColors.success;
                      balanceText = 'Owed $currency${bal.toStringAsFixed(2)}';
                    } else if (bal < -0.01) {
                      balanceColor = AppColors.error;
                      balanceText = 'Owes $currency${bal.abs().toStringAsFixed(2)}';
                    }

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: m.isAppUser ? AppColors.primary.withOpacity(0.15) : Colors.black12,
                          child: Text(
                            m.name[0].toUpperCase(),
                            style: TextStyle(
                              color: m.isAppUser ? AppColors.primary : Colors.black54,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(mName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (m.isAppUser) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.verified_rounded, color: AppColors.primary, size: 14),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          m.isAppUser ? (m.email ?? 'Registered User') : 'Manual Member',
                          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              balanceText,
                              style: TextStyle(color: balanceColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            if (!isMe && bal.abs() < 0.01) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove from Group',
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Remove Member'),
                                      content: Text('Are you sure you want to remove "${m.name}" from the group?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text('Remove', style: TextStyle(color: AppColors.error)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true && context.mounted) {
                                    await groupProvider.removeMember(widget.groupId, m.id);
                                    showTopNotification('Member removed successfully!');
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Inline Add Member Form
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -3)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invite / Add New Member', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),

                    // Add registered User by email
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Invite registered user email...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _isSearchingUser
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : ElevatedButton(
                                onPressed: _searchAndAddUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  minimumSize: const Size(0, 40),
                                ),
                                child: const Text('Invite', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Add manual member by name
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _manualNameController,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Or add manual member name...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            minimumSize: const Size(0, 40),
                          ),
                          child: const Text('Add Manual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
