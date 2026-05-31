class FeedItem {
  FeedItem({required this.kind, required this.refId, this.price, this.community, this.bedrooms, this.createdAt, this.urgency = 0});
  final String kind;
  final String refId;
  final num? price;
  final String? community;
  final int? bedrooms;
  final DateTime? createdAt;
  final int urgency;

  factory FeedItem.fromJson(Map<String, dynamic> j) => FeedItem(
        kind: j['kind']?.toString() ?? 'item',
        refId: j['ref_id']?.toString() ?? '',
        price: j['price'] is num ? j['price'] : num.tryParse('${j['price']}'),
        community: j['community'],
        bedrooms: j['bedrooms'] is int ? j['bedrooms'] : int.tryParse('${j['bedrooms']}'),
        createdAt: DateTime.tryParse('${j['created_at']}'),
        urgency: j['urgency'] is int ? j['urgency'] : int.tryParse('${j['urgency']}') ?? 0,
      );
}
