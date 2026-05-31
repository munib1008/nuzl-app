class Lead {
  Lead({required this.id, this.buyerName, this.buyerType, this.purpose, this.community, this.minBudget, this.maxBudget, this.temperature, this.qualificationSteps = 0});
  final String id;
  final String? buyerName;
  final String? buyerType;
  final String? purpose;
  final String? community;
  final num? minBudget;
  final num? maxBudget;
  final String? temperature;
  final int qualificationSteps; // 0..5

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
        id: j['id'].toString(),
        buyerName: j['buyer_name'],
        buyerType: j['buyer_type'],
        purpose: j['purpose'],
        community: j['community'],
        minBudget: j['min_budget'] is num ? j['min_budget'] : num.tryParse('${j['min_budget']}'),
        maxBudget: j['max_budget'] is num ? j['max_budget'] : num.tryParse('${j['max_budget']}'),
        temperature: j['temperature'],
        qualificationSteps: j['qualification_steps'] is int
            ? j['qualification_steps']
            : int.tryParse('${j['qualification_steps']}') ?? 0,
      );
}
