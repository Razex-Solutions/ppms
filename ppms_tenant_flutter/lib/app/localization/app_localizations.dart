import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('ur'),
  ];

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(localizations != null, 'AppLocalizations not found in context.');
    return localizations!;
  }

  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'appName': 'PPMS Tenant',
      'loginTitle': 'Sign in to your station workspace',
      'loginSubtitle':
          'Use your staff account to open only the modules and actions assigned to you.',
      'username': 'Username',
      'password': 'Password',
      'signIn': 'Sign in',
      'demoAccounts': 'Seeded local accounts',
      'loadingSession': 'Restoring your session',
      'loadingSessionHint':
          'Checking your saved login, enabled modules, and scope access.',
      'forbidden': 'Access restricted',
      'forbiddenHint':
          'Your account is active, but this area is outside your current role or scope.',
      'backToHome': 'Back to home',
      'profile': 'Profile',
      'notifications': 'Notifications',
      'overview': 'Overview',
      'managerWorkspace': 'Shift workspace',
      'operatorWorkspace': 'Self service',
      'accountantWorkspace': 'Finance workspace',
      'stationAdminWorkspace': 'Station control',
      'headOfficeWorkspace': 'Organization control',
      'masterAdminWorkspace': 'Onboarding workspace',
      'logout': 'Log out',
      'language': 'Language',
      'english': 'English',
      'urdu': 'Urdu',
      'activeModules': 'Enabled modules',
      'featureFlags': 'Feature flags',
      'permissions': 'Permission summary',
      'quickStatus': 'Quick status',
      'apiBaseUrl': 'API base URL',
      'currentRole': 'Current role',
      'scopeLevel': 'Scope level',
      'organization': 'Organization',
      'station': 'Station',
      'sessionReady': 'Foundation ready',
      'sessionReadyHint':
          'Auth, localization, responsive shell, and module-aware navigation are wired.',
      'notificationsEmpty':
          'Notification center shell is ready for in-app events and future WhatsApp/Firebase delivery.',
      'profileHint':
          'This area will hold personal details, attendance, payroll, and account settings based on role.',
      'workspaceHint':
          'This workspace shell is ready for the next feature build phase.',
      'menu': 'Menu',
      'sessionRestore': 'Session restore',
      'signInFailed': 'Sign-in failed',
      'roleModules': 'Role and modules',
      'refreshHint':
          'Session refresh automation will be added after the next API integration step.',
    },
    'ur': {
      'appName': 'پی پی ایم ایس ٹیننٹ',
      'loginTitle': 'اپنے اسٹیشن ورک اسپیس میں سائن اِن کریں',
      'loginSubtitle':
          'اپنے اسٹاف اکاؤنٹ سے صرف وہی ماڈیول اور ایکشن کھولیں جو آپ کو دیے گئے ہیں۔',
      'username': 'یوزرنیم',
      'password': 'پاس ورڈ',
      'signIn': 'سائن اِن',
      'demoAccounts': 'لوکل سیڈ اکاؤنٹس',
      'loadingSession': 'سیشن بحال کیا جا رہا ہے',
      'loadingSessionHint':
          'آپ کا محفوظ لاگ اِن، فعال ماڈیولز، اور اسکوپ ایکسیس چیک کی جا رہی ہے۔',
      'forbidden': 'رسائی محدود ہے',
      'forbiddenHint':
          'آپ کا اکاؤنٹ فعال ہے لیکن یہ حصہ آپ کے موجودہ رول یا اسکوپ سے باہر ہے۔',
      'backToHome': 'ہوم پر واپس جائیں',
      'profile': 'پروفائل',
      'notifications': 'نوٹیفکیشنز',
      'overview': 'اوورویو',
      'managerWorkspace': 'شفٹ ورک اسپیس',
      'operatorWorkspace': 'سیلف سروس',
      'accountantWorkspace': 'فنانس ورک اسپیس',
      'stationAdminWorkspace': 'اسٹیشن کنٹرول',
      'headOfficeWorkspace': 'آرگنائزیشن کنٹرول',
      'masterAdminWorkspace': 'آن بورڈنگ ورک اسپیس',
      'logout': 'لاگ آؤٹ',
      'language': 'زبان',
      'english': 'English',
      'urdu': 'اردو',
      'activeModules': 'فعال ماڈیولز',
      'featureFlags': 'فیچر فلیگز',
      'permissions': 'پرمیژن خلاصہ',
      'quickStatus': 'فوری حالت',
      'apiBaseUrl': 'اے پی آئی بیس یو آر ایل',
      'currentRole': 'موجودہ رول',
      'scopeLevel': 'اسکوپ لیول',
      'organization': 'آرگنائزیشن',
      'station': 'اسٹیشن',
      'sessionReady': 'فاؤنڈیشن تیار ہے',
      'sessionReadyHint':
          'اتھ، لوکلائزیشن، ریسپانسیو شیل، اور ماڈیول کے مطابق نیویگیشن وائر ہو چکی ہے۔',
      'notificationsEmpty':
          'نوٹیفکیشن سینٹر شیل اِن ایپ ایونٹس اور آئندہ واٹس ایپ / فائر بیس ڈیلیوری کے لئے تیار ہے۔',
      'profileHint':
          'اس حصے میں ذاتی تفصیلات، حاضری، پے رول، اور اکاؤنٹ سیٹنگز رول کے مطابق آئیں گی۔',
      'workspaceHint':
          'یہ ورک اسپیس شیل اگلے فیچر بلڈ فیز کے لئے تیار ہے۔',
      'menu': 'مینو',
      'sessionRestore': 'سیشن بحالی',
      'signInFailed': 'سائن اِن ناکام',
      'roleModules': 'رول اور ماڈیولز',
      'refreshHint':
          'سیشن ریفریش آٹومیشن اگلے اے پی آئی انٹیگریشن مرحلے میں شامل ہوگی۔',
    },
  };

  String text(String key) =>
      _strings[locale.languageCode]?[key] ?? _strings['en']![key] ?? key;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
