enum Currency {
  ngn('NGN', '₦', 'Nigerian Naira'),
  usdt('USDT', '\$', 'Tether USD');

  const Currency(this.code, this.symbol, this.currencyName);
  final String code;
  final String symbol;
  final String currencyName;
}
