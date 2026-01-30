/// 货币工具类
class CurrencyUtils {
  /// 货币代码到符号的映射
  static const Map<String, String> _symbols = {
    'CNY': '¥',  // 人民币
    'USD': '\$', // 美元
    'EUR': '€',  // 欧元
    'JPY': '¥',  // 日元
    'GBP': '£',  // 英镑
    'HKD': 'HK\$', // 港币
    'KRW': '₩',  // 韩元
    'SGD': 'S\$', // 新加坡元
    'CAD': 'C\$', // 加拿大元
    'AUD': 'A\$', // 澳大利亚元
  };

  /// 获取货币符号
  static String getSymbol(String currencyCode) {
    return _symbols[currencyCode] ?? currencyCode;
  }

  /// 格式化金额（自动添加货币符号）
  static String formatAmount(double amount, String currencyCode) {
    final symbol = getSymbol(currencyCode);
    final absAmount = amount.abs();

    // 先确定单位，再处理符号
    String formattedAmount;
    if (absAmount >= 100000000) {
      formattedAmount = '${(amount / 100000000).toStringAsFixed(2)} 亿';
    } else if (absAmount >= 10000) {
      formattedAmount = '${(amount / 10000).toStringAsFixed(2)} 万';
    } else {
      formattedAmount = amount.toStringAsFixed(2);
    }

    return '$symbol $formattedAmount';
  }

  /// 格式化金额（不添加货币符号，用于后续处理）
  static String formatAmountWithoutSymbol(double amount) {
    if (amount >= 100000000) {
      return '${(amount / 100000000).toStringAsFixed(2)} 亿';
    } else if (amount >= 10000) {
      return '${(amount / 10000).toStringAsFixed(2)} 万';
    }
    return amount.toStringAsFixed(2);
  }
}
