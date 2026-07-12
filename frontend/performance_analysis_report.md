# Finloop Application Performance Analysis Report

This report analyzes the performance bottlenecks of the Finloop application's screens and services, offering optimization strategies to improve responsiveness, reduce frame drops, and enable fluid UI interaction.

---

## 1. Executive Summary

During the analysis of the core screens (`TransactionsScreen`, `ChartsScreen`, `ManageAccountsScreen`, and `AddTransactionScreen`), we identified several key factors contributing to UI sluggishness:
1. **Redundant Iteration on the Main UI Thread**: Large data sets (like transactions) are filtered, sorted, grouped, and mapped inside build functions multiple times on every widget rebuild.
2. **Synchronous Tab Rendering**: The custom navigation pattern forces all tabs (Daily, Weekly, Monthly, Calendar, Summary) to evaluate their queries, filter lists, and build their widget trees concurrently rather than lazily when selected.
3. **Repeated/Uncached Analytics Computations**: The analytics calculations in `FinancialAnalytics` re-run expensive getters (`pieData`, `monthlyExpenses`, `maxY`) repeatedly during minor visual interactions (such as chart taps).
4. **Lack of Local Caching and Query Pagination**: The database layer pulls the entire historical collection of transactions from Firestore on a live stream, leading to scaling degradation as user history grows.
5. **Global Rebuild Triggers**: Roots of large screen trees subscribe to global provider changes (e.g. `SettingsProvider`), triggering deep subtree rebuilds for minor setting updates.

---

## 2. In-Depth Screen Analysis

### 📊 Charts Screen (`charts_screen.dart` & `financial_analytics.dart`)
The Charts screen exhibits noticeable lag during tab switches and point-selection on line/pie charts.

*   **Getter Invocation Redundancy**: 
    Inside `build()`, getters on the `FinancialAnalytics` object are invoked independently for different UI parts:
    *   `pieData` loops over all transactions.
    *   `totalCurrentMonthExpenses` loops over all transactions.
    *   `monthlyExpenses` loops 6 times over all transactions.
    *   `maxY` calls `monthlyExpenses` internally, repeating the 6-loop calculation.
    
    This results in **at least 14 full iterations** over the transaction array every time the charts rebuild, which is triggered by any micro-animation, frame tick, or touch callback.
*   **O(N * C) Nested Complexity**: 
    The `_resolveCategory` helper inside the transaction iteration does a nested loop over the user's category array to map category IDs/names.
*   **Touch Interactions**: 
    Tapping a slice on the pie chart or a point on the trend chart triggers `setState` to update the active index, causing a full rebuild of the `ChartsScreen` and repeating all the heavy computation getters.

### 📝 Transactions Screen (`transactions_screen.dart`)
This is the heaviest screen (~2,800 lines of code) and experiences frames dropping during scrolling and tab switching.

*   **Synchronous Multi-Tab Evaluation**: 
    The `StreamBuilder` wraps a `TabBarView`. Because the children list is created inline via mapping (`_tabs.map(...)`), the code synchronously calls `_filterTransactions` and `_calculateSummary` for **every tab** on every stream update or layout rebuild, instead of evaluating only the visible tab.
*   **Unnecessary List Re-Creation**: 
    The `_filterTransactions` method chains `.where(...).toList()` 5 consecutive times for starred status, search query text matching, type filtering, and account filtering. This creates multiple short-lived arrays in memory, placing a heavy load on Dart's garbage collector.
*   **Cumulative Balance Scan**: 
    `_calculateSummary` performs a chronological balance scan over the entire `allTransactions` list to calculate cumulative balance, even if the user is only viewing a single filtered month.

### 💳 Manage Accounts Screen (`manage_accounts_screen.dart`)
*   **Calculations in build()**: 
    The total balances and section sums are folded (`accounts.fold<double>(...)`) synchronously inside the `build()` method, which can stutter during scroll events.
*   **Subtree Rebuilds**: 
    Rebuilding the account list doesn't isolate the list elements into individual `const` widgets, causing all transaction statistics pills to perform string styling and date parses repeatedly.

### ➕ Add Transaction Screen (`add_transaction_screen.dart`)
*   **Form State Propagation**: 
    Typing into the description or note text field triggers build updates on the entire screen, including recalculations of dynamic account select menus, category grids, and date formats.
*   **Heavy Keyboard Lifecycle Stutter**: 
    When the soft keyboard pops up, the screen changes size, triggering a layout and rebuild of complex drop-down selections and layouts.

### 🚀 Splash Screen (`splash_screen.dart`)
*   **Asset Pre-Loading**: 
    The initial white flash on boot occurs because vector graphics (SVGs) are loaded and parsed on demand in the layout phase rather than being precached during the initialization window.

---

## 3. Recommended Optimization Strategies

### 1. Memoization & Computed Caching
*   **Solution**: Cache computed values inside the state or use a state manager to precompute calculations when raw data changes, rather than calculating on demand during `build`.
*   **Example**: Modify `_ChartsScreenState` to compute and store a single `CachedAnalytics` object inside `setState` whenever raw stream data updates, allowing the build method to access cheap pre-calculated fields.

```dart
// Instead of creating this in build():
// final analytics = FinancialAnalytics(...);

// We store and update it inside initState / Stream listeners:
_txSub = firestore.getTransactions().listen((txList) {
  setState(() {
    _allTransactions = txList;
    _cachedAnalytics = FinancialAnalytics.compute(txList, _userAccounts, _userCategories);
  });
});
```

### 2. Lazy Tab Evaluation & Tab-Specific Viewports
*   **Solution**: Deconstruct the TabBarView layout so that each tab is placed inside its own `KeepAlive` stateful widget that listens to the data stream individually or uses a selector.
*   **Action**: Only calculate search queries and summaries for the active tab index, using a `ValueNotifier` or a `TabController` listener to delay evaluation.

### 3. Single-Pass Iteration for Filtering
*   **Solution**: Refactor `_filterTransactions` from consecutive `.where().toList()` chains into a single loop that applies all active filters at once.
*   **Benefit**: Reduces memory allocations from $O(5N)$ to $O(N)$ and decreases garbage collection overhead.

```dart
// Refactored Single-Pass Filtering
final filtered = <Map<String, dynamic>>[];
for (final tx in all) {
  if (!matchesDate(tx)) continue;
  if (_showOnlyStarred && !isStarred(tx)) continue;
  if (_isSearching && !matchesSearch(tx)) continue;
  if (_filterType != 'All' && tx['type'] != _filterType) continue;
  if (_filterAccountId != null && !matchesAccount(tx)) continue;
  filtered.add(tx);
}
```

### 4. Database-Level Pagination & Constraints
*   **Solution**: Centralize Firestore queries to fetch only the active focused month or year by default (e.g., query constraints using `.where('date', isGreaterThanOrEqualTo: ...)`).
*   **Benefit**: Users with years of transaction history will load the app instantly because historical archives are only loaded on demand when changing the period selector.

### 5. Selective Consumer Usage (Rebuild Isolation)
*   **Solution**: Replace `context.watch<SettingsProvider>()` at the top of build trees with scoped `Consumer` or `Selector` widgets wrap only the specific text/buttons that depend on the settings (such as currency changes).
*   **Benefit**: Visual updates on other elements will not force the entire scrolling viewport to rebuild.
