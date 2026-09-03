import '../models/models.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/enums/transaction_status.dart';

abstract final class MockData {
  static final user = User(
    id: 'usr_001',
    firstName: 'Chukwuemeka',
    lastName: 'Adeyemi',
    email: 'emeka@example.com',
    phone: '+2348123456789',
    biometricEnabled: true,
    twoFactorEnabled: false,
    createdAt: DateTime(2025, 6, 15, 10, 30),
    verificationStatus: 'verified',
  );

  static final savingsAccount = Account(
    id: 'acc_savings_001',
    currency: 'NGN',
    balance: 1250000.00,
    usdtEquivalent: 780.42,
    exchangeRate: 1601.45,
    rateTimestamp: DateTime.now(),
  );

  static final availableAccount = Account(
    id: 'acc_available_001',
    currency: 'NGN',
    balance: 85750.50,
  );

  static final accountSummary = AccountSummary(
    savings: savingsAccount,
    available: availableAccount,
    totalNgnEquivalent: 1335750.50,
    totalUsdtEquivalent: 780.42,
    currentRate: 1601.45,
  );

  static final bankAccounts = [
    BankAccount(
      id: 'bank_001',
      bankName: 'Guaranty Trust Bank',
      bankCode: '058',
      accountNumber: '0123456789',
      accountName: 'Chukwuemeka Adeyemi',
      isDefault: true,
    ),
    BankAccount(
      id: 'bank_002',
      bankName: 'Access Bank',
      bankCode: '044',
      accountNumber: '9876543210',
      accountName: 'Chukwuemeka Adeyemi',
      isDefault: false,
    ),
  ];

  static final beneficiaries = [
    const Beneficiary(
      id: 'ben_001',
      name: 'Chidi Okonkwo',
      bank: 'Zenith Bank',
      accountNumber: '7823456109',
      isFavorite: true,
    ),
    const Beneficiary(
      id: 'ben_002',
      name: 'Ngozi Eze',
      bank: 'First Bank',
      accountNumber: '3091234567',
      isFavorite: false,
    ),
    const Beneficiary(
      id: 'ben_003',
      name: 'Tunde Bakare',
      bank: 'Access Bank',
      accountNumber: '1189000234',
      isFavorite: true,
    ),
  ];

  static String _newId(String prefix) =>
      '$prefix${DateTime.now().millisecondsSinceEpoch}';

  static BankAccount getDefaultBankAccount() {
    for (final account in bankAccounts) {
      if (account.isDefault) return account;
    }
    return bankAccounts.first;
  }

  static void addBankAccount({
    required String bankName,
    required String bankCode,
    required String accountNumber,
    required String accountName,
    required bool isDefault,
  }) {
    if (isDefault) {
      for (int i = 0; i < bankAccounts.length; i++) {
        bankAccounts[i] = bankAccounts[i].copyWith(isDefault: false);
      }
    }
    bankAccounts.add(BankAccount(
      id: _newId('bank_'),
      bankName: bankName,
      bankCode: bankCode,
      accountNumber: accountNumber,
      accountName: accountName,
      isDefault: isDefault,
    ));
  }

  static void removeBankAccount(String id) {
    bankAccounts.removeWhere((a) => a.id == id);
    if (!bankAccounts.any((a) => a.isDefault) && bankAccounts.isNotEmpty) {
      bankAccounts[0] = bankAccounts.first.copyWith(isDefault: true);
    }
  }

  static void setDefaultBankAccount(String id) {
    for (int i = 0; i < bankAccounts.length; i++) {
      bankAccounts[i] = bankAccounts[i].copyWith(isDefault: bankAccounts[i].id == id);
    }
  }

  static void addBeneficiary({
    required String name,
    required String bank,
    required String accountNumber,
    bool isFavorite = false,
  }) {
    beneficiaries.add(Beneficiary(
      id: _newId('ben_'),
      name: name,
      bank: bank,
      accountNumber: accountNumber,
      isFavorite: isFavorite,
    ));
  }

  static void removeBeneficiary(String id) {
    beneficiaries.removeWhere((b) => b.id == id);
  }

  static void toggleFavoriteBeneficiary(String id) {
    final index = beneficiaries.indexWhere((b) => b.id == id);
    if (index >= 0) {
      beneficiaries[index] = beneficiaries[index].copyWith(
        isFavorite: !beneficiaries[index].isFavorite,
      );
    }
  }

  static void updateBeneficiary(Beneficiary updated) {
    final index = beneficiaries.indexWhere((b) => b.id == updated.id);
    if (index >= 0) {
      beneficiaries[index] = updated;
    }
  }

  static final exchangeRate = ExchangeRate(
    pair: 'NGN/USDT',
    rate: 1601.45,
    inverseRate: 0.000624,
    fee: 0.5,
    minAmount: 1000,
    maxAmount: 5000000,
    timestamp: DateTime.now(),
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
    status: 'active',
  );

  static final transactions = [
    Transaction(
      id: 'txn_001',
      type: TransactionType.deposit,
      amount: 100000.00,
      currency: 'NGN',
      status: TransactionStatus.completed,
      date: DateTime(2025, 9, 1, 10, 15),
      description: 'Bank Transfer — GTBank',
      reference: 'DEP-20250901-001',
    ),
    Transaction(
      id: 'txn_002',
      type: TransactionType.conversion,
      amount: 100000.00,
      currency: 'NGN',
      status: TransactionStatus.completed,
      date: DateTime(2025, 9, 1, 10, 16),
      reference: 'CNV-20250901-001',
      fromCurrency: 'NGN',
      toCurrency: 'USDT',
      convertedAmount: 62.34,
      exchangeRate: 1604.50,
      fee: 500.00,
    ),
    Transaction(
      id: 'txn_003',
      type: TransactionType.savings,
      amount: 62.34,
      currency: 'USDT',
      status: TransactionStatus.completed,
      date: DateTime(2025, 9, 1, 10, 16, 30),
      reference: 'SAV-20250901-001',
    ),
    Transaction(
      id: 'txn_004',
      type: TransactionType.withdrawal,
      amount: 20000.00,
      currency: 'NGN',
      status: TransactionStatus.completed,
      date: DateTime(2025, 8, 28, 14, 20),
      destination: 'GTBank •• 4521',
      reference: 'WTH-20250828-001',
    ),
    Transaction(
      id: 'txn_005',
      type: TransactionType.deposit,
      amount: 250000.00,
      currency: 'NGN',
      status: TransactionStatus.completed,
      date: DateTime(2025, 8, 25, 9, 0),
      description: 'Bank Transfer — Access Bank',
      reference: 'DEP-20250825-001',
    ),
    Transaction(
      id: 'txn_006',
      type: TransactionType.transfer,
      amount: 15000.00,
      currency: 'NGN',
      status: TransactionStatus.completed,
      date: DateTime(2025, 8, 22, 11, 45),
      destination: 'Chidi Okonkwo — Zenith Bank •• 7823',
      reference: 'TRF-20250822-001',
    ),
    Transaction(
      id: 'txn_007',
      type: TransactionType.conversion,
      amount: 200000.00,
      currency: 'NGN',
      status: TransactionStatus.completed,
      date: DateTime(2025, 8, 20, 16, 0),
      reference: 'CNV-20250820-001',
      fromCurrency: 'NGN',
      toCurrency: 'USDT',
      convertedAmount: 125.80,
      exchangeRate: 1589.30,
      fee: 1000.00,
    ),
    Transaction(
      id: 'txn_008',
      type: TransactionType.deposit,
      amount: 500000.00,
      currency: 'NGN',
      status: TransactionStatus.completed,
      date: DateTime(2025, 8, 15, 8, 30),
      description: 'Bank Transfer — First Bank',
      reference: 'DEP-20250815-001',
    ),
    Transaction(
      id: 'txn_009',
      type: TransactionType.withdrawal,
      amount: 50000.00,
      currency: 'NGN',
      status: TransactionStatus.processing,
      date: DateTime(2025, 9, 2, 9, 10),
      destination: 'Access Bank •• 1189',
      reference: 'WTH-20250902-001',
    ),
    Transaction(
      id: 'txn_010',
      type: TransactionType.transfer,
      amount: 25000.00,
      currency: 'NGN',
      status: TransactionStatus.failed,
      date: DateTime(2025, 8, 18, 13, 22),
      destination: 'Unknown Account — UBA •• 3341',
      failureReason: 'Invalid account details',
      reference: 'TRF-20250818-001',
    ),
    Transaction(
      id: 'txn_011',
      type: TransactionType.deposit,
      amount: 350000.00,
      currency: 'NGN',
      status: TransactionStatus.completed,
      date: DateTime(2025, 8, 10, 10, 0),
      description: 'Bank Transfer — Zenith Bank',
      reference: 'DEP-20250810-001',
    ),
    Transaction(
      id: 'txn_012',
      type: TransactionType.conversion,
      amount: 150000.00,
      currency: 'NGN',
      status: TransactionStatus.completed,
      date: DateTime(2025, 8, 5, 15, 30),
      reference: 'CNV-20250805-001',
      fromCurrency: 'NGN',
      toCurrency: 'USDT',
      convertedAmount: 94.60,
      exchangeRate: 1585.00,
      fee: 750.00,
    ),
  ];

  static final processingTransaction = Transaction(
    id: 'txn_013',
    type: TransactionType.withdrawal,
    amount: 50000.00,
    currency: 'NGN',
    status: TransactionStatus.processing,
    date: DateTime.now(),
    destination: 'Access Bank •• 1189',
    reference: 'WTH-${DateTime.now().millisecondsSinceEpoch}',
  );
}
