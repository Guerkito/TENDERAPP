import 'package:flutter_test/flutter_test.dart';
import 'package:tenderapp/models/loyalty.dart';

void main() {
  test('sellos actuales y premios disponibles', () {
    final recienCompleta =
        LoyaltySummary.fromTotals(totalStamps: 7, rewardsRedeemed: 0, goal: 6);
    expect(recienCompleta.currentStamps, 6);
    expect(recienCompleta.rewardsAvailable, 1);

    final despuesDeCanjear =
        LoyaltySummary.fromTotals(totalStamps: 7, rewardsRedeemed: 1, goal: 6);
    expect(despuesDeCanjear.currentStamps, 1);
    expect(despuesDeCanjear.rewardsAvailable, 0);

    final dosTarjetas =
        LoyaltySummary.fromTotals(totalStamps: 12, rewardsRedeemed: 1, goal: 6);
    expect(dosTarjetas.currentStamps, 6);
    expect(dosTarjetas.rewardsAvailable, 1);

    final sinMeta =
        LoyaltySummary.fromTotals(totalStamps: 3, rewardsRedeemed: 0, goal: 0);
    expect(sinMeta.currentStamps, 0);
    expect(sinMeta.rewardsAvailable, 0);
  });
}
