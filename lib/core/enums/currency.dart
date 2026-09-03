enum Currency {
  NGN('NGN', '₦', 'Nigerian Naira'),
  USDT('USDT', '\$', 'Tether USD');

  const Currency(this.code, this.symbol, this.currencyName);
  final String code;
  final String symbol;
  final String currencyName;
}
