import 'package:flutter/material.dart';

class ColorSelector extends StatelessWidget {
  final List<String> colors;
  final String selectedColorHex;
  final ValueChanged<String> onColorSelected;

  const ColorSelector({
    super.key,
    required this.colors,
    required this.selectedColorHex,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        itemBuilder: (context, index) {
          final colorHex = colors[index];
          final isSelected = selectedColorHex == colorHex;
          final color = Color(int.parse(colorHex.replaceAll('#', '0xFF')));

          return GestureDetector(
            onTap: () => onColorSelected(colorHex),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          );
        },
      ),
    );
  }
}
