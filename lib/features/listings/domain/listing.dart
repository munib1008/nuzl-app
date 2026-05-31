class Listing {
  Listing({required this.id, required this.price, this.purpose, this.status, this.availability, this.community, this.bedrooms, this.sizeSqft});
  final String id;
  final num price;
  final String? purpose;
  final String? status;
  final String? availability;
  final String? community;
  final int? bedrooms;
  final num? sizeSqft;

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        id: j['id'].toString(),
        price: j['price'] is num ? j['price'] : num.tryParse('${j['price']}') ?? 0,
        purpose: j['purpose'],
        status: j['status'],
        availability: j['availability_status'],
        community: j['community'],
        bedrooms: j['bedrooms'] is int ? j['bedrooms'] : int.tryParse('${j['bedrooms']}'),
        sizeSqft: j['size_sqft'] is num ? j['size_sqft'] : num.tryParse('${j['size_sqft']}'),
      );
}
