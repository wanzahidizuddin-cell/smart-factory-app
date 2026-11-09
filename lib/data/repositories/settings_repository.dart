class AppSettings {
  const AppSettings({
    this.language = 'en',
    this.currency = 'USD',
    this.stockUnit = 'kg',
  });

  final String language;
  final String currency;
  final String stockUnit;

  AppSettings copyWith({
    String? language,
    String? currency,
    String? stockUnit,
  }) =>
      AppSettings(
        language: language ?? this.language,
        currency: currency ?? this.currency,
        stockUnit: stockUnit ?? this.stockUnit,
      );
}

class SettingsRepository {
  AppSettings _settings = const AppSettings();

  AppSettings load() => _settings;

  AppSettings save(AppSettings settings) {
    if (!const {'en', 'es', 'ms'}.contains(settings.language) ||
        !const {'USD', 'EUR', 'MYR'}.contains(settings.currency) ||
        !const {'kg', 'lbs', 'units'}.contains(settings.stockUnit)) {
      throw ArgumentError.value(settings, 'settings', 'Unsupported preference.');
    }
    _settings = settings;
    return _settings;
  }
}
