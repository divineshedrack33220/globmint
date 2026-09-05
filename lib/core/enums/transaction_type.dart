enum TransactionType {
  deposit('Deposit'),
  withdrawal('Withdrawal'),
  conversion('Conversion'),
  transfer('Transfer'),
  savings('Savings'),
  fee('Fee'),
  adjustment('Adjustment'),
  reversal('Reversal');

  const TransactionType(this.label);
  final String label;
}
