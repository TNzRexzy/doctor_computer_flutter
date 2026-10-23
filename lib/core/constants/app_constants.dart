/// Core constant values used across the app.
class AppConstants {
  AppConstants._();

  static const String appName = 'Doctor Computer';
  static const String appTagline = 'Your Trusted Tech Partner';
  static const String appVersion = '1.0.9-beta';

  static const double standardBuildFee = 250000.0;
  static const double premiumBuildFee = 500000.0;
  
  static const int pointsMultiplier = 1; // 1 point per Rp10,000

  static const List<Map<String, dynamic>> shippingMethods = [
    {
      'name': 'Reguler',
      'price': 15000.0,
      'days': '3-5',
    },
    {
      'name': 'Ekspres',
      'price': 30000.0,
      'days': '1-2',
    },
    {
      'name': 'Hari Ini',
      'price': 50000.0,
      'days': 'Hari ini',
    },
  ];

  static const List<String> paymentMethods = [
    'Transfer Bank BCA',
    'Transfer Bank Mandiri',
    'Transfer Bank BNI',
    'GoPay',
    'OVO',
    'Dana',
    'ShopeePay',
    'COD'
  ];
}
