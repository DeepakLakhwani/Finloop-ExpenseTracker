import 'package:flutter/material.dart';

class CardPreview extends StatelessWidget {
  final String currency;
  final String limitText;
  final String usedText;
  final String issuerText;
  final String nameText;
  final String colorHex;

  const CardPreview({
    super.key,
    required this.currency,
    required this.limitText,
    required this.usedText,
    required this.issuerText,
    required this.nameText,
    required this.colorHex,
  });

  @override
  Widget build(BuildContext context) {
    final limitVal = double.tryParse(limitText.isNotEmpty ? limitText : '0') ?? 0.0;
    final usedVal = double.tryParse(usedText.isNotEmpty ? usedText : '0') ?? 0.0;
    final availableVal = limitVal - usedVal;

    final displayIssuer = issuerText.isNotEmpty ? issuerText : 'Bank Issuer';
    final displayName = nameText.isNotEmpty ? nameText : 'Card Name';

    Color cardColor = Color(int.parse(colorHex.replaceAll('#', '0xFF')));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor, cardColor.withValues(alpha: 0.82)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.24),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  displayIssuer.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.credit_card, color: Colors.white70, size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            displayName.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AVAILABLE CREDIT',
                    style: TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currency ${availableVal.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'USED AMOUNT',
                    style: TextStyle(color: Colors.white60, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$currency ${usedVal.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
