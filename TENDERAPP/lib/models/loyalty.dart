class LoyaltySummary {
  final int totalStamps;
  final int goal;
  final int rewardsRedeemed;
  final int currentStamps;
  final int rewardsAvailable;

  const LoyaltySummary({
    required this.totalStamps,
    required this.goal,
    required this.rewardsRedeemed,
    required this.currentStamps,
    required this.rewardsAvailable,
  });

  factory LoyaltySummary.fromTotals({
    required int totalStamps,
    required int rewardsRedeemed,
    required int goal,
  }) {
    if (goal <= 0) {
      return LoyaltySummary(
        totalStamps: totalStamps,
        goal: 0,
        rewardsRedeemed: rewardsRedeemed,
        currentStamps: 0,
        rewardsAvailable: 0,
      );
    }
    final earned = totalStamps ~/ goal;
    final available = earned - rewardsRedeemed;
    final current = totalStamps - goal * rewardsRedeemed;
    final currentCapped =
        current < 0 ? 0 : (current > goal ? goal : current);
    return LoyaltySummary(
      totalStamps: totalStamps,
      goal: goal,
      rewardsRedeemed: rewardsRedeemed,
      currentStamps: currentCapped,
      rewardsAvailable: available < 0 ? 0 : available,
    );
  }
}

class LoyaltyBoardRow {
  final int customerId;
  final String name;
  final String? phone;
  final LoyaltySummary summary;

  const LoyaltyBoardRow({
    required this.customerId,
    required this.name,
    required this.phone,
    required this.summary,
  });
}
