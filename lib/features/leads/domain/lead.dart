class Lead {
  Lead({
    required this.id,
    this.buyerName,
    this.buyerType,
    this.purpose,
    this.community,
    this.minBudget,
    this.maxBudget,
    this.temperature,
    this.qualificationSteps = 0,
    this.status,
    this.leadCategory,
    this.phone,
    this.priority,
    this.source,
    this.propertyType,
    this.createdAt,
    this.lastActivityAt,
  });
  final String id;
  final String? buyerName;
  final String? buyerType;
  final String? purpose;
  final String? community;
  final num? minBudget;
  final num? maxBudget;
  final String? temperature;
  final int qualificationSteps; // 0..5
  final String? status; // new/contacted/qualified/viewing_scheduled/negotiating/converted/lost
  final String? leadCategory; // general/potential/qualified
  final String? phone;
  final String? priority;
  final String? source;
  final String? propertyType;
  final DateTime? createdAt;
  final DateTime? lastActivityAt;

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
        status: j['status'],
        leadCategory: j['lead_category'],
        phone: j['buyer_phone'],
        priority: j['priority'],
        source: j['source'],
        propertyType: j['property_type'],
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}'),
        lastActivityAt: DateTime.tryParse('${j['last_activity_at'] ?? ''}'),
      );
}
