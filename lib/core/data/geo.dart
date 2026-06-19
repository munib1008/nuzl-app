/// Lightweight geo reference data for profile pickers — GCC-first, with a broad
/// spread of expat-origin countries. Lists aren't exhaustive on purpose: the
/// pickers allow a custom typed value, so anything missing is still enterable.
library;

/// Common nationalities (demonyms) — GCC + the largest expat communities first,
/// then a broad alphabetical spread.
const List<String> kNationalities = [
  'Emirati', 'Saudi', 'Qatari', 'Kuwaiti', 'Bahraini', 'Omani',
  'Indian', 'Pakistani', 'Bangladeshi', 'Filipino', 'Sri Lankan', 'Nepalese',
  'Egyptian', 'Jordanian', 'Lebanese', 'Syrian', 'Palestinian', 'Iraqi', 'Yemeni',
  'Sudanese', 'Moroccan', 'Tunisian', 'Algerian', 'Iranian', 'Turkish',
  'British', 'Irish', 'American', 'Canadian', 'Australian', 'New Zealander',
  'French', 'German', 'Italian', 'Spanish', 'Portuguese', 'Dutch', 'Belgian',
  'Swiss', 'Austrian', 'Swedish', 'Norwegian', 'Danish', 'Finnish',
  'Polish', 'Russian', 'Ukrainian', 'Romanian', 'Greek', 'Hungarian', 'Czech',
  'Chinese', 'Japanese', 'Korean', 'Indonesian', 'Malaysian', 'Singaporean',
  'Thai', 'Vietnamese', 'Afghan', 'Kazakh', 'Uzbek',
  'Nigerian', 'Kenyan', 'Ghanaian', 'Ethiopian', 'South African', 'Ugandan',
  'Tanzanian', 'Somali', 'Zimbabwean',
  'Brazilian', 'Argentine', 'Mexican', 'Colombian', 'Venezuelan', 'Chilean',
  'Peruvian', 'Other',
];

/// Countries — GCC first, then the largest source markets, then a broad spread.
const List<String> kCountries = [
  'United Arab Emirates', 'Saudi Arabia', 'Qatar', 'Kuwait', 'Bahrain', 'Oman',
  'India', 'Pakistan', 'Bangladesh', 'Philippines', 'Sri Lanka', 'Nepal',
  'Egypt', 'Jordan', 'Lebanon', 'Syria', 'Iraq', 'Yemen', 'Palestine',
  'Sudan', 'Morocco', 'Tunisia', 'Algeria', 'Iran', 'Turkey',
  'United Kingdom', 'Ireland', 'United States', 'Canada', 'Australia', 'New Zealand',
  'France', 'Germany', 'Italy', 'Spain', 'Portugal', 'Netherlands', 'Belgium',
  'Switzerland', 'Austria', 'Sweden', 'Norway', 'Denmark', 'Finland',
  'Poland', 'Russia', 'Ukraine', 'Romania', 'Greece', 'Hungary', 'Czechia',
  'China', 'Japan', 'South Korea', 'Indonesia', 'Malaysia', 'Singapore',
  'Thailand', 'Vietnam', 'Afghanistan', 'Kazakhstan', 'Uzbekistan',
  'Nigeria', 'Kenya', 'Ghana', 'Ethiopia', 'South Africa', 'Uganda',
  'Tanzania', 'Somalia', 'Zimbabwe',
  'Brazil', 'Argentina', 'Mexico', 'Colombia', 'Venezuela', 'Chile',
  'Peru', 'Other',
];

/// Cities/emirates per country — GCC is complete; major source markets carry
/// their main cities. Countries not listed fall back to free-typed entry.
const Map<String, List<String>> kCitiesByCountry = {
  'United Arab Emirates': [
    'Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Ras Al Khaimah',
    'Fujairah', 'Umm Al Quwain', 'Al Ain',
  ],
  'Saudi Arabia': [
    'Riyadh', 'Jeddah', 'Mecca', 'Medina', 'Dammam', 'Khobar', 'Dhahran',
    'Tabuk', 'Abha', 'Taif', 'Buraidah', 'NEOM',
  ],
  'Qatar': ['Doha', 'Al Rayyan', 'Al Wakrah', 'Lusail', 'Al Khor', 'Umm Salal'],
  'Kuwait': ['Kuwait City', 'Hawalli', 'Salmiya', 'Al Ahmadi', 'Al Jahra', 'Farwaniya'],
  'Bahrain': ['Manama', 'Riffa', 'Muharraq', 'Hamad Town', 'Isa Town', 'Sitra'],
  'Oman': ['Muscat', 'Salalah', 'Sohar', 'Nizwa', 'Sur', 'Seeb', 'Barka'],
  'India': [
    'Mumbai', 'Delhi', 'Bengaluru', 'Hyderabad', 'Chennai', 'Kolkata', 'Pune',
    'Ahmedabad', 'Kochi', 'Kozhikode', 'Thiruvananthapuram', 'Jaipur', 'Lucknow',
    'Chandigarh', 'Surat',
  ],
  'Pakistan': ['Karachi', 'Lahore', 'Islamabad', 'Rawalpindi', 'Faisalabad', 'Multan', 'Peshawar'],
  'Bangladesh': ['Dhaka', 'Chittagong', 'Sylhet', 'Khulna', 'Rajshahi'],
  'Philippines': ['Manila', 'Quezon City', 'Cebu', 'Davao', 'Makati', 'Pasig'],
  'Sri Lanka': ['Colombo', 'Kandy', 'Galle', 'Jaffna', 'Negombo'],
  'Nepal': ['Kathmandu', 'Pokhara', 'Lalitpur', 'Biratnagar'],
  'Egypt': ['Cairo', 'Alexandria', 'Giza', 'Sharm El Sheikh', 'Port Said', 'Luxor'],
  'Jordan': ['Amman', 'Zarqa', 'Irbid', 'Aqaba'],
  'Lebanon': ['Beirut', 'Tripoli', 'Sidon', 'Jounieh'],
  'United Kingdom': ['London', 'Manchester', 'Birmingham', 'Leeds', 'Glasgow', 'Liverpool', 'Edinburgh'],
  'United States': ['New York', 'Los Angeles', 'Chicago', 'Houston', 'Miami', 'San Francisco', 'Washington DC', 'Dallas'],
  'Canada': ['Toronto', 'Vancouver', 'Montreal', 'Calgary', 'Ottawa', 'Edmonton'],
  'Australia': ['Sydney', 'Melbourne', 'Brisbane', 'Perth', 'Adelaide'],
  'France': ['Paris', 'Marseille', 'Lyon', 'Nice', 'Toulouse'],
  'Germany': ['Berlin', 'Munich', 'Frankfurt', 'Hamburg', 'Cologne', 'Stuttgart'],
  'Turkey': ['Istanbul', 'Ankara', 'Izmir', 'Antalya', 'Bursa'],
  'China': ['Beijing', 'Shanghai', 'Shenzhen', 'Guangzhou', 'Hong Kong', 'Chengdu'],
  'Russia': ['Moscow', 'Saint Petersburg', 'Novosibirsk', 'Yekaterinburg'],
  'Nigeria': ['Lagos', 'Abuja', 'Kano', 'Port Harcourt', 'Ibadan'],
  'South Africa': ['Johannesburg', 'Cape Town', 'Durban', 'Pretoria'],
  'Iran': ['Tehran', 'Mashhad', 'Isfahan', 'Shiraz', 'Tabriz'],
};
