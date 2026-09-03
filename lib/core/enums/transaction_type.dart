enum TransactionType {
  deposit('Deposit'),
  withdrawal('Withdrawal'),
  conversion('Conversion'),
  transfer('Transfer'),
  savings('Savings');

  const TransactionType(this.label);
  final String label;
}
