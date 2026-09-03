import 'dart:async';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/enums/transaction_status.dart';
import 'mock_data.dart';

class MockBalanceService {
  Future<AccountSummary> getAccountSummary() async {
    await Future.delayed(AppConstants.mockDelay);
    return MockData.accountSummary;
  }

  Future<ExchangeRate> getCurrentRate() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockData.exchangeRate;
  }

  Future<List<Transaction>> getRecentTransactions({int limit = 5}) async {
    await Future.delayed(AppConstants.mockDelay);
    final sorted = List<Transaction>.from(MockData.transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(limit).toList();
  }

  Future<List<Transaction>> getTransactions({
    TransactionType? type,
    TransactionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    await Future.delayed(AppConstants.mockDelay);
    var filtered = List<Transaction>.from(MockData.transactions);

    if (type != null) {
      filtered = filtered.where((t) => t.type == type).toList();
    }
    if (status != null) {
      filtered = filtered.where((t) => t.status == status).toList();
    }
    if (startDate != null) {
      filtered = filtered.where((t) => t.date.isAfter(startDate)).toList();
    }
    if (endDate != null) {
      filtered = filtered.where((t) => t.date.isBefore(endDate)).toList();
    }

    filtered.sort((a, b) => b.date.compareTo(a.date));
    final start = (page - 1) * pageSize;
    if (start >= filtered.length) return [];
    return filtered.sublist(start, (start + pageSize).clamp(0, filtered.length));
  }
}
