import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class CurrencySettingsScreen extends StatefulWidget {
  const CurrencySettingsScreen({super.key});

  @override
  State<CurrencySettingsScreen> createState() => _CurrencySettingsScreenState();
}

class _CurrencySettingsScreenState extends State<CurrencySettingsScreen> {
  String _searchQuery = '';
  late String _selectedCurrency;

  final List<Map<String, String>> _currencies = [
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'GBP', 'name': 'British Pound Sterling', 'symbol': '£'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'CNY', 'name': 'Chinese Yuan Renminbi', 'symbol': '¥'},
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
    {'code': 'CHF', 'name': 'Swiss Franc', 'symbol': 'Fr'},
    {'code': 'SGD', 'name': 'Singapore Dollar', 'symbol': 'S\$'},
    {'code': 'HKD', 'name': 'Hong Kong Dollar', 'symbol': 'HK\$'},
    {'code': 'NZD', 'name': 'New Zealand Dollar', 'symbol': 'NZ\$'},
    {'code': 'KRW', 'name': 'South Korean Won', 'symbol': '₩'},
    {'code': 'AED', 'name': 'UAE Dirham', 'symbol': 'د.إ'},
    {'code': 'SAR', 'name': 'Saudi Riyal', 'symbol': 'ر.س'},
    {'code': 'RUB', 'name': 'Russian Ruble', 'symbol': '₽'},
    {'code': 'THB', 'name': 'Thai Baht', 'symbol': '฿'},
    {'code': 'MYR', 'name': 'Malaysian Ringgit', 'symbol': 'RM'},
    {'code': 'ZAR', 'name': 'South African Rand', 'symbol': 'R'},
    {'code': 'TRY', 'name': 'Turkish Lira', 'symbol': '₺'},
  ];

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _selectedCurrency = settings.currencyCode;
  }

  void _saveChanges() {
    context.read<SettingsProvider>().setCurrency(_selectedCurrency);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Currency settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Currency Settings Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Active: $_selectedCurrency',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search currencies...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.grey,
                  size: 18,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Currency List
            Column(
              children: _currencies
                  .where(
                    (c) =>
                        c['name']!.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ) ||
                        c['code']!.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                  )
                  .map((c) => _buildCurrencyItem(c))
                  .toList(),
            ),
            const SizedBox(height: 32),

            // Save Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CustomButton(text: 'Save Changes', onPressed: _saveChanges),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyItem(Map<String, String> currency) {
    final isSelected = _selectedCurrency == currency['code'];
    return GestureDetector(
      onTap: () => setState(() => _selectedCurrency = currency['code']!),
      child: Container(
        color: Colors.transparent, // Ensures the entire row is tap-targetable
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.08)
                          : const Color(0xFFEBF2FF)),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    currency['symbol']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency['code']!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      currency['name']!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.neutral,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.white, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
