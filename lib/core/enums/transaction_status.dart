enum TransactionStatus {
  initiated('Initiated'),
  processing('Processing'),
  completed('Completed'),
  failed('Failed'),
  cancelled('Cancelled'),
  reversed('Reversed');

  const TransactionStatus(this.label);
  final String label;
}
