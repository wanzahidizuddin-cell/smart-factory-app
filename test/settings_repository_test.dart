import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_factory_qc/data/repositories/settings_repository.dart';
import 'package:smart_factory_qc/features/shared/providers/app_state.dart';

void main() {
  test('settings selections remain available after listeners close', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(settingsProvider, (_, __) {});

    final controller = container.read(settingsProvider.notifier);
    controller
      ..setLanguage('ms')
      ..setCurrency('MYR')
      ..setStockUnit('lbs');
    subscription.close();

    final settings = container.read(settingsProvider);
    expect(settings.language, 'ms');
    expect(settings.currency, 'MYR');
    expect(settings.stockUnit, 'lbs');
  });

  test('settings repository rejects unsupported options', () {
    final repository = SettingsRepository();

    expect(
      () => repository.save(const AppSettings(language: 'fr')),
      throwsArgumentError,
    );
    expect(
      () => repository.save(const AppSettings(currency: 'GBP')),
      throwsArgumentError,
    );
    expect(
      () => repository.save(const AppSettings(stockUnit: 'stone')),
      throwsArgumentError,
    );
  });
}
