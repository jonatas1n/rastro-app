import 'package:flutter_test/flutter_test.dart';
import 'package:rastro/services/spending_insight_config.dart';

void main() {
  test('limiares padrão de variação', () {
    expect(SpendingInsightConfig.moderatePct, 25);
    expect(SpendingInsightConfig.strongPct, 40);
    expect(SpendingInsightConfig.minPastDaysForDayAverage, 3);
  });

  test('faixas de teto', () {
    expect(SpendingInsightConfig.limitBand80, 80);
    expect(SpendingInsightConfig.limitBand100, 100);
    expect(SpendingInsightConfig.limitBand120, 120);
  });
}
