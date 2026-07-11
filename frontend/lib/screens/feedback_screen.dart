import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_colors.dart';
import '../providers/language_provider.dart';
import '../main.dart';
import '../services/firestore_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();

  String _feedbackType = 'Bug Report';
  final List<String> _feedbackTypes = [
    'Bug Report',
    'Feature Request',
    'General Feedback',
    'Support Inquiry',
  ];

  XFile? _selectedFile;
  int? _selectedFileLength;
  Uint8List? _selectedFileBytes;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      _emailController.text = user!.email!;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final int size = await image.length();
        if (size > 5 * 1024 * 1024) {
          showTopNotification(
            context.translate('err_image_too_large'),
            isError: true,
          );
          return;
        }

        Uint8List? bytes;
        if (kIsWeb) {
          bytes = await image.readAsBytes();
        }

        setState(() {
          _selectedFile = image;
          _selectedFileLength = size;
          _selectedFileBytes = bytes;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error picking image: $e');
      showTopNotification(
        '${context.translate('err_gallery_access')}: $e',
        isError: true,
      );
    }
  }

  void _removeImage() => setState(() {
        _selectedFile = null;
        _selectedFileLength = null;
        _selectedFileBytes = null;
      });

  // FIX #3: Safely unwrap result.data — it may be null or not a Map if the
  // Cloud Function throws or returns an unexpected shape.
  Future<bool> _sendEmail({
    required String type,
    required String message,
    required String? imageUrl,
    required String deviceInfo,
    required String timestamp,
    required String appVersion,
    required String email,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'sendFeedbackEmail',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call({
        'type': type,
        'message': message,
        'imageUrl': imageUrl ?? 'No attachment',
        'deviceInfo': deviceInfo,
        'timestamp': timestamp,
        'appVersion': appVersion,
        'email': email,
      });

      // FIX #3: Use explicit type check instead of bare map access.
      final data = result.data;
      if (data is Map) {
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('Error sending email: $e');
      return false;
    }
  }

  Future<void> _submitFeedback() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    final userEmail = _emailController.text.trim();
    final userId = user?.uid ?? 'anonymous_user';

    String? imageUrl;
    if (_selectedFile != null) {
      imageUrl = 'Screenshot: ${_selectedFile!.name} (Upload Bypassed)';
    }

    final now = DateTime.now().toUtc();
    final timestampStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} UTC';

    String deviceInfo = 'Unknown Platform';
    if (kIsWeb) {
      deviceInfo = 'Web Browser';
    } else {
      deviceInfo = defaultTargetPlatform.name.toUpperCase();
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersionStr =
          'FinLoop ${packageInfo.version} (${packageInfo.buildNumber})';
      final feedbackVersionStr =
          '${packageInfo.version}+${packageInfo.buildNumber}';

      final feedbackData = {
        'userId': userId,
        'userEmail': userEmail,
        'feedbackType': _feedbackType,
        'message': _messageController.text.trim(),
        if (imageUrl != null) 'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'deviceInfo': deviceInfo,
        'appVersion': feedbackVersionStr,
      };

      final firestoreService = context.read<FirestoreService>();
      await firestoreService.submitFeedback(feedbackData);
      await _sendEmail(
        type: _feedbackType,
        message: feedbackData['message'] as String,
        imageUrl: imageUrl,
        deviceInfo: deviceInfo,
        timestamp: timestampStr,
        appVersion: appVersionStr,
        email: userEmail,
      );

      if (mounted) {
        showTopNotification(
          context.translate('msg_feedback_success'),
          isError: false,
        );
        _messageController.clear();
        Navigator.pop(context);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error initiating feedback: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        showTopNotification(
          '${context.translate('err_submission_failed')}: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // FIX #7: Wrap with PopScope to block back navigation while a submission
    // is in progress, preventing the user from escaping mid-upload.
    return PopScope(
      canPop: !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSubmitting) {
          showTopNotification(
            context.translate('msg_feedback_submitting'),
            isError: false,
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          ),
          title: Text(
            context.translate('feedback'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 40,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  AppColors.primary.withValues(alpha: 0.15),
                                  AppColors.primary.withValues(alpha: 0.05),
                                ]
                              : [
                                  AppColors.primary.withValues(alpha: 0.08),
                                  AppColors.primary.withValues(alpha: 0.02),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.primary.withValues(
                            alpha: isDark ? 0.2 : 0.15,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.support_agent_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                context.translate('header_feedback_intro'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.translate('desc_feedback_intro'),
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                          Divider(
                            height: 24,
                            thickness: 1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.mail_outline_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.translate(
                                    'desc_feedback_support_email',
                                  ),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Topic Selector ──────────────────────────────────────
                    Text(
                      context.translate('header_select_topic'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _feedbackTypes.map((type) {
                        final isSelected = _feedbackType == type;
                        String getLocalizedType(String t) {
                          switch (t) {
                            case 'Bug Report':
                              return context.translate('type_bug');
                            case 'Feature Request':
                              return context.translate('type_feature');
                            case 'General Feedback':
                              return context.translate('type_feedback');
                            case 'Support Inquiry':
                              return context.translate('type_support');
                            default:
                              return t;
                          }
                        }

                        // FIX #6: Replace deprecated selectedColor with the
                        // color resolver API to avoid lint warnings in newer
                        // Flutter versions (3.19+).
                        return ChoiceChip(
                          label: Text(getLocalizedType(type)),
                          selected: isSelected,
                          showCheckmark: false,
                          color: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.primary.withValues(alpha: 0.15);
                            }
                            return Colors.transparent;
                          }),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.12),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _feedbackType = type);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ── Email Field ─────────────────────────────────────────
                    Text(
                      context.translate('header_your_email'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      maxLines: 1,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: context.translate('hint_email_input'),
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.translate('err_email_empty');
                        }
                        final emailRegExp = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        );
                        if (!emailRegExp.hasMatch(value.trim())) {
                          return context.translate('err_email_invalid');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Message Field ───────────────────────────────────────
                    Text(
                      context.translate('header_your_message'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 6,
                      maxLength: 1000,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: context.translate('hint_message_input'),
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.translate('err_message_empty');
                        }
                        if (value.trim().length < 10) {
                          return context.translate('err_message_too_short');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Attachment ──────────────────────────────────────────
                    Text(
                      context.translate('header_attachment'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_selectedFile != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: kIsWeb && _selectedFileBytes != null
                                    ? Image.memory(
                                        _selectedFileBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        File(_selectedFile!.path),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFile!.name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${((_selectedFileLength ?? 0) / 1024).toStringAsFixed(1)} KB',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                              onPressed: _removeImage,
                              tooltip: context.translate(
                                'tooltip_remove_attachment',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4),
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.translate('btn_add_screenshot'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.translate('desc_attachment_limits'),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 36),

                    // ── Submit Button ───────────────────────────────────────
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      icon: Icon(
                        Icons.send_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 18,
                      ),
                      label: Text(
                        context.translate('feedback'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
