import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme/app_colors.dart';
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

  PlatformFile? _selectedFile;
  bool _isSubmitting = false;
  String _submissionStatus = '';

  // FIX #1: Track upload task and stream subscription so they can be
  // cancelled on dispose or mid-flight widget removal.
  UploadTask? _activeUploadTask;
  StreamSubscription<TaskSnapshot>? _uploadProgressSubscription;

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
    // FIX #1 continued: Cancel any in-flight upload to avoid setState
    // calls on a dead widget and to free resources.
    _uploadProgressSubscription?.cancel();
    _activeUploadTask?.cancel();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.first;

        // Check if we have valid image data (bytes on web, path on mobile)
        final hasData = kIsWeb ? pickedFile.bytes != null : pickedFile.path != null;
        if (!hasData) {
          showTopNotification('Could not read image data', isError: true);
          return;
        }

        if (pickedFile.size > 5 * 1024 * 1024) {
          showTopNotification('Image must be smaller than 5MB', isError: true);
          return;
        }
        setState(() => _selectedFile = pickedFile);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error picking image: $e');
      showTopNotification('Failed to access gallery: $e', isError: true);
    }
  }

  void _removeImage() => setState(() => _selectedFile = null);

  Future<String?> _uploadImage(PlatformFile file, String userId) async {
    try {
      final ref = FirebaseStorage.instance.ref(
        'feedback/${userId}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (kIsWeb) {
        if (file.bytes == null) return null;
        _activeUploadTask = ref.putData(file.bytes!);
      } else {
        if (file.path == null) return null;
        _activeUploadTask = ref.putFile(File(file.path!));
      }

      // FIX #1 continued: Store the subscription so it can be cancelled in
      // dispose() if the user leaves the screen during upload.
      _uploadProgressSubscription = _activeUploadTask!.snapshotEvents.listen((
        snapshot,
      ) {
        if (snapshot.totalBytes > 0 && mounted) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() {
            _submissionStatus =
                'Uploading screenshot... ${(progress * 100).toStringAsFixed(0)}%';
          });
        }
      });

      final snapshot = await _activeUploadTask!;

      // Clean up references now that the upload is complete.
      await _uploadProgressSubscription?.cancel();
      _uploadProgressSubscription = null;
      _activeUploadTask = null;

      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (kDebugMode) debugPrint('Error uploading image: $e');
      await _uploadProgressSubscription?.cancel();
      _uploadProgressSubscription = null;
      _activeUploadTask = null;
      return null;
    }
  }

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

      // Show immediate success feedback and pop the screen
      showTopNotification(
        'Feedback received! Thank you for helping us improve.',
        isError: false,
      );

      _messageController.clear();
      if (mounted) {
        Navigator.pop(context);
      }

      // Execute network operations in the background silently
      () async {
        try {
          await FirestoreService().submitFeedback(feedbackData);
          await _sendEmail(
            type: _feedbackType,
            message: feedbackData['message'] as String,
            imageUrl: imageUrl,
            deviceInfo: deviceInfo,
            timestamp: timestampStr,
            appVersion: appVersionStr,
            email: userEmail,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Background feedback submission error: $e');
          }
        }
      }();
    } catch (e) {
      if (kDebugMode) debugPrint('Error initiating feedback: $e');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        showTopNotification('Submission error: $e', isError: true);
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
            'Please wait while your feedback is being submitted.',
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
            'Feedback',
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
                                  const Color(0xFFEBF2FF),
                                  const Color(0xFFF9FBFF),
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
                              const Icon(
                                Icons.support_agent_rounded,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'How can we help you?',
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
                            'Have a bug to report or an idea for a feature? Fill out the form below. Your message along with device diagnostics will be sent directly to our support team.',
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
                              const Icon(
                                Icons.mail_outline_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'If you do not receive a confirmation or reply within 48 hours, please feel free to reach out directly at support.finloop@gmail.com.',
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
                      'SELECT TOPIC',
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
                        // FIX #6: Replace deprecated selectedColor with the
                        // color resolver API to avoid lint warnings in newer
                        // Flutter versions (3.19+).
                        return ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
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
                      'YOUR EMAIL',
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
                        hintText: 'Enter your email address...',
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
                          borderSide: const BorderSide(
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
                          return 'Please enter your email';
                        }
                        final emailRegExp = RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                        if (!emailRegExp.hasMatch(value.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Message Field ───────────────────────────────────────
                    Text(
                      'YOUR MESSAGE',
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
                        hintText:
                            'Please describe the issue or share your ideas here...',
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
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a message';
                        }
                        if (value.trim().length < 10) {
                          return 'Message should be at least 10 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // ── Attachment ──────────────────────────────────────────
                    Text(
                      'ATTACHMENT (OPTIONAL)',
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
                                child: _selectedFile!.bytes != null
                                    ? Image.memory(
                                        _selectedFile!.bytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : (_selectedFile!.path != null
                                        ? Image.file(
                                            File(_selectedFile!.path!),
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(
                                            Icons.image_outlined,
                                            size: 32,
                                            color: Colors.grey,
                                          )),
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
                                    '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
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
                              tooltip: 'Remove Attachment',
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
                                'Add Screenshot or Image',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'PNG, JPG up to 5MB',
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
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Submit Feedback',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
