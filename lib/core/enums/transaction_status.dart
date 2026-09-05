enum TransactionStatus {
  initiated('Initiated'),
  pending('Pending'),
  authorized('Authorized'),
  processing('Processing'),
  submitted('Submitted'),
  confirmed('Confirmed'),
  completed('Completed'),
  failed('Failed'),
  cancelled('Cancelled'),
  reversed('Reversed'),
  expired('Expired');

  const TransactionStatus(this.label);
  final String label;
}
