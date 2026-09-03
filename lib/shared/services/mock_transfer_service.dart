import 'dart:async';
import '../models/models.dart';
import '../../core/constants/app_constants.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/enums/transaction_status.dart';
import 'mock_data.dart';

class MockTransferService {
  Future<Transaction> withdraw({
    required double amount,
    required String currency,
    required BankAccount destination,
  }) async {
    await Future.delayed(AppConstants.mockLongDelay);
    return Transaction(
      id: 'wth_${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.withdrawal,
      amount: amount,
      currency: currency,
      status: TransactionStatus.completed,
      date: DateTime.now(),
      destination: destination.displayName,
      reference: 'WTH-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<Transaction> bankTransfer({
    required double amount,
    required String currency,
    required String bankName,
    required String accountNumber,
    required String accountName,
    String? narration,
  }) async {
    await Future.delayed(AppConstants.mockLongDelay);
    return Transaction(
      id: 'trf_${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.transfer,
      amount: amount,
      currency: currency,
      status: TransactionStatus.completed,
      date: DateTime.now(),
      destination: '$accountName — $bankName •••• ${accountNumber.substring(accountNumber.length - 4)}',
      reference: 'TRF-${DateTime.now().millisecondsSinceEpoch}',
      description: narration,
    );
  }

  Future<Transaction> deposit({
    required double amount,
    required String currency,
  }) async {
    await Future.delayed(AppConstants.mockLongDelay);
    return Transaction(
      id: 'dep_${DateTime.now().millisecondsSinceEpoch}',
      type: TransactionType.deposit,
      amount: amount,
      currency: currency,
      status: TransactionStatus.completed,
      date: DateTime.now(),
      description: 'Bank Transfer',
      reference: 'DEP-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<List<Beneficiary>> getBeneficiaries() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return MockData.beneficiaries;
  }

  Future<String?> resolveAccount(String accountNumber) async {
    await Future.delayed(const Duration(milliseconds: 500));
    for (final beneficiary in MockData.beneficiaries) {
      if (beneficiary.accountNumber == accountNumber) return beneficiary.name;
    }
    if (accountNumber == '1122334455') return 'Chukwuemeka Adeyemi';
    return null;
  }

  Future<List<BankAccount>> getSavedAccounts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockData.bankAccounts;
  }
}
