import 'package:flutter/material.dart';

class FeesInputDialog extends StatefulWidget {
  final double initialFees;
  final ValueChanged<double> onSave;

  const FeesInputDialog({
    super.key,
    required this.initialFees,
    required this.onSave,
  });

  @override
  State<FeesInputDialog> createState() => _FeesInputDialogState();
}

class _FeesInputDialogState extends State<FeesInputDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialFees > 0 ? widget.initialFees.toString() : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transaction Fees'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: TextFormField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Enter fees amount'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final fees = double.tryParse(_controller.text) ?? 0.0;
            widget.onSave(fees);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
