// Translation tables. Foundation set = the most visible chrome + the language
// selector; the rest is translated surface-by-surface (nav → auth → dashboard →
// CRM → marketplace). Swap these maps for ARB / a remote translation service
// later without touching call sites (everything goes through context.tr).

const Map<String, String> kEn = {
  // Language selector
  'language': 'Language',
  'choose_language': 'Choose language',
  'english': 'English',
  'arabic': 'العربية',
  // Common actions
  'save': 'Save',
  'cancel': 'Cancel',
  'submit': 'Submit',
  'search': 'Search',
  'back': 'Back',
  'next': 'Next',
  'done': 'Done',
  'logout': 'Logout',
  // Core nav
  'dashboard': 'Dashboard',
  'properties': 'Properties',
  'my_properties': 'My Properties',
  'marketplace': 'Marketplace',
  'crm': 'CRM',
  'community': 'Community',
  'messages': 'Messages',
  'feed': 'Feed',
  'orders': 'Orders',
  'cart': 'Cart',
  'settings': 'Settings',
  'profile_settings': 'Profile & settings',
};

const Map<String, String> kAr = {
  // Language selector
  'language': 'اللغة',
  'choose_language': 'اختر اللغة',
  'english': 'English',
  'arabic': 'العربية',
  // Common actions
  'save': 'حفظ',
  'cancel': 'إلغاء',
  'submit': 'إرسال',
  'search': 'بحث',
  'back': 'رجوع',
  'next': 'التالي',
  'done': 'تم',
  'logout': 'تسجيل الخروج',
  // Core nav
  'dashboard': 'لوحة التحكم',
  'properties': 'العقارات',
  'my_properties': 'عقاراتي',
  'marketplace': 'السوق',
  'crm': 'إدارة العملاء',
  'community': 'المجتمع',
  'messages': 'الرسائل',
  'feed': 'المنشورات',
  'orders': 'الطلبات',
  'cart': 'السلة',
  'settings': 'الإعدادات',
  'profile_settings': 'الملف الشخصي والإعدادات',
};
