class RevenueCatConfig {
  // Apple App Store Connect Product ID: com.screenshare.castnow.vip.year
  // Subscription Group Reference Name: sub-by-year
  static const String appleApiKey =
      'appl_QMxRGpTZxPOMmDsLMwEQJKhupTk'; // Linked to com.screenshare.castnow.vip.year entitlement in RevenueCat
  static const String googleApiKey = ''; // If you have Android, put it here
  static const String entitlementID = 'com.screenshare.castnow.vip.year';
  // RevenueCat Dashboard > Offerings 中配置的 Offering ID（用于付费墙统计 fallback）
  static const String offeringId = 'default';
}

