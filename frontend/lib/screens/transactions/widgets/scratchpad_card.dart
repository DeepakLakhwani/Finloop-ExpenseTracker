import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_colors.dart';

class ScratchpadCard extends StatefulWidget {
  final String userId;
  final Stream<DocumentSnapshot>? scratchpadStream;

  const ScratchpadCard({
    super.key,
    required this.userId,
    this.scratchpadStream,
  });

  @override
  State<ScratchpadCard> createState() => _ScratchpadCardState();
}

class _ScratchpadCardState extends State<ScratchpadCard> {
  late TextEditingController _scratchpadController;
  late FocusNode _scratchpadFocusNode;
  Timer? _debounceTimer;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _scratchpadController = TextEditingController();
    _scratchpadFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scratchpadController.dispose();
    _scratchpadFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('notes')
            .doc('scratchpad')
            .set({
          'content': text,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error auto-saving notes: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.scratchpadStream ?? FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('notes')
          .doc('scratchpad')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isInitialized) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data!.exists && !_isInitialized) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          _scratchpadController.text = data['content'] ?? '';
          _isInitialized = true;
        } else if (!snapshot.hasData || !snapshot.data!.exists) {
          _isInitialized = true;
        }

        return GestureDetector(
          onTap: () {
            _scratchpadFocusNode.requestFocus();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            color: Theme.of(context).colorScheme.surface,
            width: double.infinity,
            height: double.infinity,
            child: TextField(
              controller: _scratchpadController,
              focusNode: _scratchpadFocusNode,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                height: 1.5,
              ),
              decoration: InputDecoration(
                filled: false,
                fillColor: Colors.transparent,
                hintText: 'Type your notes here...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: _onTextChanged,
            ),
          ),
        );
      },
    );
  }
}
