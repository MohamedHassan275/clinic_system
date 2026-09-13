enum PaymentMethod {
  cash('cash', 'نقدي (كاش)'),
  card('card', 'بطاقة إلكترونية / فيزا'),
  transfer('transfer', 'تحويل بنكي'),
  insurance('insurance', 'تأمين صحي / تعاقد');

  final String dbValue;
  final String displayName;

  const PaymentMethod(this.dbValue, this.displayName);

  static PaymentMethod fromString(String? val) {
    if (val == null || val.isEmpty) return PaymentMethod.cash;
    final v = val.trim().toLowerCase();
    if (v == 'card' || v == 'visa' || v == 'فيزا / كارت' || v == 'فيزا') return PaymentMethod.card;
    if (v == 'transfer' || v == 'bank' || v == 'تحويل بنكي') return PaymentMethod.transfer;
    if (v == 'insurance' || v == 'تأمين') return PaymentMethod.insurance;
    return PaymentMethod.cash;
  }
}
