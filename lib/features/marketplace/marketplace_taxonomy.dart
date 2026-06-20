/// Controlled marketplace taxonomy — replaces the old free-text "Category" field.
///
/// Two top-level kinds (service / product). Each maps category → subcategories.
/// Listings store `category` (the group, e.g. "Cleaning") and `subcategory`
/// (the specific item, e.g. "Deep Cleaning"). Filter chips use the category.
class MarketplaceTaxonomy {
  const MarketplaceTaxonomy._();

  /// Service categories grouped by sector, flattened to category → subcategories.
  static const Map<String, List<String>> service = {
    // Residential
    'Cleaning': ['Deep Cleaning', 'Move In Cleaning', 'Move Out Cleaning', 'Sofa Cleaning', 'Carpet Cleaning', 'Window Cleaning'],
    'Maintenance': ['Handyman', 'Electrical', 'Plumbing', 'AC Maintenance', 'Water Heater', 'Appliance Repair'],
    'Painting': ['Interior Painting', 'Exterior Painting', 'Villa Painting', 'Apartment Painting'],
    'Car Services': ['Car Wash', 'Mobile Car Wash', 'Car Detailing', 'Ceramic Coating'],
    'Landscaping': ['Gardening', 'Irrigation', 'Tree Trimming', 'Lawn Maintenance'],
    'Security': ['CCTV', 'Smart Locks', 'Alarm Systems', 'Access Control'],
    'Moving': ['Relocation', 'Packing', 'Furniture Assembly'],
    // Hospitality
    'Housekeeping': ['Hotel Cleaning', 'Daily Housekeeping', 'Linen Service'],
    'Facility Management': ['Building Maintenance', 'MEP Services', 'HVAC Maintenance'],
    'Pest Control': ['Residential', 'Commercial'],
    'Laundry': ['Laundry Collection', 'Commercial Laundry'],
    'Catering': ['Event Catering', 'Corporate Catering'],
  };

  /// Product categories → subcategories.
  static const Map<String, List<String>> product = {
    'Furniture': ['Sofa', 'Dining', 'Bedroom', 'Outdoor'],
    'Appliances': ['Refrigerator', 'Washing Machine', 'Dryer', 'Dishwasher'],
    'Smart Home': ['Cameras', 'Smart Locks', 'Sensors'],
    'Construction': ['Paint', 'Tiles', 'Doors', 'Flooring'],
    'Landscaping': ['Plants', 'Outdoor Furniture', 'Irrigation'],
    'Hospitality Supplies': ['Hotel Furniture', 'Linen', 'Kitchen Equipment'],
  };

  /// The category→subcategory map for a kind ('service' | 'product').
  static Map<String, List<String>> forKind(String kind) =>
      kind == 'product' ? product : service;

  static List<String> categories(String kind) => forKind(kind).keys.toList();

  static List<String> subcategories(String kind, String? category) =>
      (category == null) ? const [] : (forKind(kind)[category] ?? const []);
}
