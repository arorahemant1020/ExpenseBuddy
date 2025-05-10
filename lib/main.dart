import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExpenseBuddy',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.light,
        fontFamily: 'Roboto',
        cardTheme: CardTheme(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [];
  final ExpenseTrackerHome _expenseTrackerHome = ExpenseTrackerHome();
  final AnalyticsPage _analyticsPage = AnalyticsPage();
  final SavingsPage _savingsPage = SavingsPage();

  @override
  void initState() {
    super.initState();
    _screens.add(_expenseTrackerHome);
    _screens.add(_analyticsPage);
    _screens.add(_savingsPage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.savings), label: 'Savings'),
        ],
      ),
    );
  }
}

class ExpenseTrackerHome extends StatefulWidget {
  const ExpenseTrackerHome({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ExpenseTrackerHomeState createState() => _ExpenseTrackerHomeState();
}

class _ExpenseTrackerHomeState extends State<ExpenseTrackerHome> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Food';
  List<Expense> _expenses = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  final List<String> _categories = [
    'Food',
    'Fuel',
    'Shopping',
    'Entertainment',
    'Bills',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = prefs.getStringList('expenses') ?? [];

    setState(() {
      _expenses =
          expensesJson.map((json) {
            final Map<String, dynamic> data = jsonDecode(json);
            return Expense(
              id: data['id'],
              description: data['description'],
              amount: data['amount'],
              category: data['category'],
              date: DateTime.parse(data['date']),
            );
          }).toList();
      _isLoading = false;
    });
  }

  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson =
        _expenses
            .map(
              (expense) => jsonEncode({
                'id': expense.id,
                'description': expense.description,
                'amount': expense.amount,
                'category': expense.category,
                'date': expense.date.toIso8601String(),
              }),
            )
            .toList();

    await prefs.setStringList('expenses', expensesJson);
  }

  double get _monthlyExpense {
    final now = DateTime.now();
    return _expenses
        .where(
          (expense) =>
              expense.date.year == now.year && expense.date.month == now.month,
        )
        .fold(0, (sum, expense) => sum + expense.amount);
  }

  List<Expense> get _filteredExpenses {
    return _expenses
        .where(
          (expense) =>
              expense.date.year == _selectedDate.year &&
              expense.date.month == _selectedDate.month &&
              expense.date.day == _selectedDate.day,
        )
        .toList();
  }

  double? get _maxExpenseOfDay {
    if (_filteredExpenses.isEmpty) return null;
    return _filteredExpenses
        .map((e) => e.amount)
        .reduce((a, b) => a > b ? a : b);
  }

  double? get _minExpenseOfDay {
    if (_filteredExpenses.isEmpty) return null;
    return _filteredExpenses
        .map((e) => e.amount)
        .reduce((a, b) => a < b ? a : b);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _addExpense() async {
    final description = _descriptionController.text;
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (description.isNotEmpty && amount > 0) {
      final id = DateTime.now().millisecondsSinceEpoch;

      setState(() {
        _expenses.add(
          Expense(
            id: id,
            description: description,
            amount: amount,
            category: _selectedCategory,
            date: _selectedDate,
          ),
        );
        _descriptionController.clear();
        _amountController.clear();
        _selectedCategory = 'Food'; // Reset to default category
      });

      await _saveExpenses();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Expense added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editExpense(Expense expense) async {
    _descriptionController.text = expense.description;
    _amountController.text = expense.amount.toString();
    _selectedCategory = expense.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Expense',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items:
                    _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
                },
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final description = _descriptionController.text;
                  final amount = double.tryParse(_amountController.text) ?? 0.0;

                  if (description.isNotEmpty && amount > 0) {
                    setState(() {
                      final index = _expenses.indexWhere(
                        (e) => e.id == expense.id,
                      );
                      if (index != -1) {
                        _expenses[index] = Expense(
                          id: expense.id,
                          description: description,
                          amount: amount,
                          category: _selectedCategory,
                          date: expense.date,
                        );
                      }
                    });

                    await _saveExpenses();
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Expense updated successfully!'),
                        backgroundColor: Colors.blue,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text('Update Expense'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _descriptionController.clear();
                  _amountController.clear();
                },
                child: Text('Cancel'),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteExpense(int id) async {
    setState(() {
      _expenses.removeWhere((expense) => expense.id == id);
    });

    await _saveExpenses();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Expense deleted successfully!'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Expense Tracker'), elevation: 0),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Fixed Monthly Expense Header
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Theme.of(context).primaryColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Expenses',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          'Rs. ${_monthlyExpense.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Date Selector
                  Card(
                    margin: EdgeInsets.all(16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Selected Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.calendar_today),
                            onPressed: () => _selectDate(context),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Add New Expense',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                      value: _selectedCategory,
                                      decoration: InputDecoration(
                                        labelText: 'Category',
                                        prefixIcon: Icon(Icons.category),
                                      ),
                                      items:
                                          _categories.map((String category) {
                                            return DropdownMenuItem<String>(
                                              value: category,
                                              child: Text(category),
                                            );
                                          }).toList(),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            _selectedCategory = newValue;
                                          });
                                        }
                                      },
                                    ),
                                    SizedBox(height: 16),
                                    TextField(
                                      controller: _descriptionController,
                                      decoration: InputDecoration(
                                        labelText: 'Description',
                                        prefixIcon: Icon(Icons.description),
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    TextField(
                                      controller: _amountController,
                                      decoration: InputDecoration(
                                        labelText: 'Amount',
                                        prefixIcon: Icon(Icons.currency_rupee),
                                      ),
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                    ),
                                    SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _addExpense,
                                      child: Text('Add Expense'),
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Today's stats
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Max Today',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            _maxExpenseOfDay != null
                                                ? 'Rs. ${_maxExpenseOfDay!.toStringAsFixed(2)}'
                                                : 'Rs. 0.00',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Min Today',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            _minExpenseOfDay != null
                                                ? 'Rs. ${_minExpenseOfDay!.toStringAsFixed(2)}'
                                                : 'Rs. 0.00',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Expenses on ${DateFormat('MMM d, yyyy').format(_selectedDate)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          _filteredExpenses.isEmpty
                              ? Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long,
                                        size: 80,
                                        color: Colors.grey[400],
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'No expenses on this date',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              : ListView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                itemCount: _filteredExpenses.length,
                                itemBuilder: (context, index) {
                                  final expense = _filteredExpenses[index];
                                  return Card(
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor.withOpacity(0.2),
                                        child: Icon(
                                          _getCategoryIcon(expense.category),
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      title: Text(expense.description),
                                      subtitle: Text(
                                        '${expense.category} • ${DateFormat('MMM d, yyyy').format(expense.date)}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Rs. ${expense.amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert),
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _editExpense(expense);
                                              } else if (value == 'delete') {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (context) => AlertDialog(
                                                        title: Text(
                                                          'Delete Expense',
                                                        ),
                                                        content: Text(
                                                          'Are you sure you want to delete this expense?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                    ),
                                                            child: Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              _deleteExpense(
                                                                expense.id,
                                                              );
                                                            },
                                                            child: Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                (context) => [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.edit,
                                                          color: Colors.blue,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text('Edit'),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.delete,
                                                          color: Colors.red,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text('Delete'),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Fuel':
        return Icons.local_gas_station;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Entertainment':
        return Icons.movie;
      case 'Bills':
        return Icons.receipt;
      default:
        return Icons.attach_money;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}

class AnalyticsPage extends StatefulWidget {
  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  List<Expense> _expenses = [];
  bool _isLoading = true;
  String _timeFrame = 'Month'; // 'Month', 'Week', 'Year'
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = prefs.getStringList('expenses') ?? [];

    setState(() {
      _expenses =
          expensesJson.map((json) {
            final Map<String, dynamic> data = jsonDecode(json);
            return Expense(
              id: data['id'],
              description: data['description'],
              amount: data['amount'],
              category: data['category'],
              date: DateTime.parse(data['date']),
            );
          }).toList();
      _isLoading = false;
    });
  }

  List<Expense> get _filteredExpenses {
    switch (_timeFrame) {
      case 'Week':
        final weekStart = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - 1),
        );
        return _expenses
            .where(
              (expense) =>
                  expense.date.isAfter(weekStart.subtract(Duration(days: 1))) &&
                  expense.date.isBefore(weekStart.add(Duration(days: 7))),
            )
            .toList();
      case 'Year':
        return _expenses
            .where((expense) => expense.date.year == _selectedDate.year)
            .toList();
      case 'Month':
      default:
        return _expenses
            .where(
              (expense) =>
                  expense.date.year == _selectedDate.year &&
                  expense.date.month == _selectedDate.month,
            )
            .toList();
    }
  }

  Map<String, double> get _categoryTotals {
    final Map<String, double> totals = {};

    for (var expense in _filteredExpenses) {
      if (totals.containsKey(expense.category)) {
        totals[expense.category] = totals[expense.category]! + expense.amount;
      } else {
        totals[expense.category] = expense.amount;
      }
    }

    return totals;
  }

  List<Color> get _categoryColors {
    return [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Expense Analytics'), elevation: 0),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Theme.of(context).primaryColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total $_timeFrame Expenses',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Rs. ${_filteredExpenses.fold(0.0, (sum, expense) => sum + expense.amount).toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${DateFormat('MMMM yyyy').format(_selectedDate)}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              InkWell(
                                onTap: () => _selectMonth(context),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white70),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Change Month',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.calendar_month,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Expense Breakdown by Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    if (_filteredExpenses.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.bar_chart,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No expenses to analyze',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // Simple bar chart representation
                      Container(
                        height: 200,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children:
                              _categoryTotals.entries.map((entry) {
                                final category = entry.key;
                                final amount = entry.value;
                                final maxAmount = _categoryTotals.values.reduce(
                                  (a, b) => a > b ? a : b,
                                );
                                final percentage = (amount / maxAmount) * 100;
                                final index = _categoryTotals.keys
                                    .toList()
                                    .indexOf(category);

                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          height: (percentage * 1.5).clamp(
                                            20,
                                            150,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _categoryColors[index %
                                                    _categoryColors.length],
                                            borderRadius: BorderRadius.vertical(
                                              top: Radius.circular(8),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),

                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Category Breakdown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: _categoryTotals.length,
                      itemBuilder: (context, index) {
                        final category = _categoryTotals.keys.elementAt(index);
                        final amount = _categoryTotals[category]!;
                        final percentage =
                            _filteredExpenses.isEmpty
                                ? 0.0
                                : (amount /
                                        _filteredExpenses.fold(
                                          0.0,
                                          (sum, expense) =>
                                              sum + expense.amount,
                                        )) *
                                    100;

                        return Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _categoryColors[index %
                                      _categoryColors.length],
                              child: Icon(
                                _getCategoryIcon(category),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(category),
                            subtitle: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _categoryColors[index % _categoryColors.length],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Rs. ${amount.toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Fuel':
        return Icons.local_gas_station;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Entertainment':
        return Icons.movie;
      case 'Bills':
        return Icons.receipt;
      default:
        return Icons.attach_money;
    }
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadExpenses();
    }
  }
}

class SavingsPage extends StatefulWidget {
  @override
  _SavingsPageState createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> {
  double _monthlyIncome = 0.0;
  double _totalSavings = 0.0;
  double _totalInvestments = 0.0;
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<Transaction> _monthlySavings = [];
  List<Transaction> _monthlyInvestments = [];

  @override
  void initState() {
    super.initState();
    _loadData().then((_) {
      _filterTransactions();
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _monthlyIncome = prefs.getDouble('monthly_income') ?? 0.0;
      _totalSavings = prefs.getDouble('total_savings') ?? 0.0;
      _totalInvestments = prefs.getDouble('total_investments') ?? 0.0;

      final transactionsJson =
          prefs.getStringList('savings_transactions') ?? [];
      _transactions =
          transactionsJson.map((json) {
            final Map<String, dynamic> data = jsonDecode(json);
            return Transaction(
              id: data['id'],
              description: data['description'],
              amount: data['amount'],
              type: data['type'],
              date: DateTime.parse(data['date']),
            );
          }).toList();

      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('monthly_income', _monthlyIncome);
    await prefs.setDouble('total_savings', _totalSavings);
    await prefs.setDouble('total_investments', _totalInvestments);

    final transactionsJson =
        _transactions
            .map(
              (transaction) => jsonEncode({
                'id': transaction.id,
                'description': transaction.description,
                'amount': transaction.amount,
                'type': transaction.type,
                'date': transaction.date.toIso8601String(),
              }),
            )
            .toList();

    await prefs.setStringList('savings_transactions', transactionsJson);
  }

  Future<void> _updateMonthlyIncome() async {
    final TextEditingController controller = TextEditingController(
      text: _monthlyIncome > 0 ? _monthlyIncome.toString() : '',
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Update Monthly Income'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monthly Income',
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final amount = double.tryParse(controller.text) ?? 0.0;
                  if (amount > 0) {
                    setState(() {
                      _monthlyIncome = amount;
                    });
                    _saveData();
                    Navigator.pop(context);
                  }
                },
                child: Text('Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _addTransaction(String type) async {
    _amountController.clear();
    _descriptionController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add ${type.capitalize()}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final description = _descriptionController.text;
                  final amount = double.tryParse(_amountController.text) ?? 0.0;

                  if (description.isNotEmpty && amount > 0) {
                    final transaction = Transaction(
                      id: DateTime.now().millisecondsSinceEpoch,
                      description: description,
                      amount: amount,
                      type: type,
                      date: DateTime.now(),
                    );

                    setState(() {
                      _transactions.add(transaction);
                      if (type == 'savings') {
                        _totalSavings += amount;
                      } else {
                        _totalInvestments += amount;
                      }
                    });

                    _saveData();
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${type.capitalize()} added successfully!',
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text('Add ${type.capitalize()}'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<double> _getMonthlyExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final expensesJson = prefs.getStringList('expenses') ?? [];

    final expenses =
        expensesJson.map((json) {
          final Map<String, dynamic> data = jsonDecode(json);
          return Expense(
            id: data['id'],
            description: data['description'],
            amount: data['amount'],
            category: data['category'],
            date: DateTime.parse(data['date']),
          );
        }).toList();

    return expenses
        .where(
          (expense) =>
              expense.date.year == _selectedDate.year &&
              expense.date.month == _selectedDate.month,
        )
        .fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Savings & Investments'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _updateMonthlyIncome,
            tooltip: 'Update Monthly Income',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Theme.of(context).primaryColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly Income',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Rs. ${_monthlyIncome.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${DateFormat('MMMM yyyy').format(_selectedDate)}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              InkWell(
                                onTap: () => _selectMonth(context),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white70),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Change Month',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.calendar_month,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    FutureBuilder<double>(
                      future: _getMonthlyExpenses(),
                      builder: (context, snapshot) {
                        final expenses = snapshot.data ?? 0.0;
                        final monthlySavingsTotal = _monthlySavings.fold(
                          0.0,
                          (sum, transaction) => sum + transaction.amount,
                        );
                        final monthlyInvestmentsTotal = _monthlyInvestments
                            .fold(
                              0.0,
                              (sum, transaction) => sum + transaction.amount,
                            );
                        final availableBalance =
                            _monthlyIncome -
                            expenses -
                            monthlySavingsTotal -
                            monthlyInvestmentsTotal;

                        return Padding(
                          padding: EdgeInsets.all(16),
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monthly Summary',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Income:'),
                                      Text(
                                        'Rs. ${_monthlyIncome.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Expenses:'),
                                      Text(
                                        'Rs. ${expenses.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (monthlySavingsTotal > 0) ...[
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Monthly Savings:'),
                                        Text(
                                          'Rs. ${monthlySavingsTotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (monthlyInvestmentsTotal > 0) ...[
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Monthly Investments:'),
                                        Text(
                                          'Rs. ${monthlyInvestmentsTotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  Divider(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Available Balance:'),
                                      Text(
                                        'Rs. ${availableBalance.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              availableBalance >= 0
                                                  ? Colors.green
                                                  : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total Savings',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Rs. ${_totalSavings.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed:
                                          () => _addTransaction('savings'),
                                      child: Text('Add Savings'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(
                                      'Total Investments',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Rs. ${_totalInvestments.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed:
                                          () => _addTransaction('investment'),
                                      child: Text('Add Investment'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Recent Transactions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    _transactions.isEmpty
                        ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet,
                                  size: 80,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No transactions yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final transaction =
                                _transactions[_transactions.length - 1 - index];
                            return Card(
                              margin: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      transaction.type == 'savings'
                                          ? Colors.blue.withOpacity(0.2)
                                          : Colors.green.withOpacity(0.2),
                                  child: Icon(
                                    transaction.type == 'savings'
                                        ? Icons.savings
                                        : Icons.trending_up,
                                    color:
                                        transaction.type == 'savings'
                                            ? Colors.blue
                                            : Colors.green,
                                  ),
                                ),
                                title: Text(transaction.description),
                                subtitle: Text(
                                  '${transaction.type.capitalize()} • ${DateFormat('MMM d, yyyy').format(transaction.date)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Rs. ${transaction.amount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _editTransaction(transaction);
                                        } else if (value == 'delete') {
                                          showDialog(
                                            context: context,
                                            builder:
                                                (context) => AlertDialog(
                                                  title: Text(
                                                    'Delete ${transaction.type.capitalize()}',
                                                  ),
                                                  content: Text(
                                                    'Are you sure you want to delete this ${transaction.type}?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                          ),
                                                      child: Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        _deleteTransaction(
                                                          transaction,
                                                        );
                                                      },
                                                      child: Text(
                                                        'Delete',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );
                                        }
                                      },
                                      itemBuilder:
                                          (context) => [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.edit,
                                                    color: Colors.blue,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Edit'),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text('Delete'),
                                                ],
                                              ),
                                            ),
                                          ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                    SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }

  // Add these methods to the _SavingsPageState class, just before the build method:

  Future<void> _editTransaction(Transaction transaction) async {
    _descriptionController.text = transaction.description;
    _amountController.text = transaction.amount.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit ${transaction.type.capitalize()}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final description = _descriptionController.text;
                  final newAmount =
                      double.tryParse(_amountController.text) ?? 0.0;

                  if (description.isNotEmpty && newAmount > 0) {
                    setState(() {
                      // Adjust the total amounts
                      if (transaction.type == 'savings') {
                        _totalSavings =
                            _totalSavings - transaction.amount + newAmount;
                      } else {
                        _totalInvestments =
                            _totalInvestments - transaction.amount + newAmount;
                      }

                      // Update the transaction
                      final index = _transactions.indexWhere(
                        (t) => t.id == transaction.id,
                      );
                      if (index != -1) {
                        _transactions[index] = Transaction(
                          id: transaction.id,
                          description: description,
                          amount: newAmount,
                          type: transaction.type,
                          date: transaction.date,
                        );
                      }
                    });

                    _saveData();
                    _filterTransactions();
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${transaction.type.capitalize()} updated successfully!',
                        ),
                        backgroundColor: Colors.blue,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text('Update ${transaction.type.capitalize()}'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _descriptionController.clear();
                  _amountController.clear();
                },
                child: Text('Cancel'),
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    setState(() {
      // Adjust the total amounts
      if (transaction.type == 'savings') {
        _totalSavings -= transaction.amount;
      } else {
        _totalInvestments -= transaction.amount;
      }

      // Remove the transaction
      _transactions.removeWhere((t) => t.id == transaction.id);
    });

    await _saveData();
    _filterTransactions();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${transaction.type.capitalize()} deleted successfully!'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Now modify the ListView.builder in the build method to include edit and delete options
  // Replace the existing ListView.builder in the SavingsPage build method with this:
  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _filterTransactions() {
    setState(() {
      _monthlySavings =
          _transactions
              .where(
                (transaction) =>
                    transaction.type == 'savings' &&
                    transaction.date.year == _selectedDate.year &&
                    transaction.date.month == _selectedDate.month,
              )
              .toList();

      _monthlyInvestments =
          _transactions
              .where(
                (transaction) =>
                    transaction.type == 'investment' &&
                    transaction.date.year == _selectedDate.year &&
                    transaction.date.month == _selectedDate.month,
              )
              .toList();
    });
  }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _filterTransactions();
    }
  }
}

class Expense {
  final int id;
  final String description;
  final double amount;
  final String category;
  final DateTime date;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
  });
}

class Transaction {
  final int id;
  final String description;
  final double amount;
  final String type; // 'savings' or 'investment'
  final DateTime date;

  Transaction({
    required this.id,
    required this.description,
    required this.amount,
    required this.type,
    required this.date,
  });
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1)}";
  }
}
