import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'locale_cubit.dart';

/// Provides [AppStrings] down the tree (safe in build + callbacks).
class AppStringsScope extends InheritedWidget {
  const AppStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStringsScope>();
    if (scope != null) return scope.strings;
    // Fallback when above MaterialApp (splash) or before scope mounts.
    return AppStrings.fromLocale(context.read<LocaleCubit>().state);
  }

  @override
  bool updateShouldNotify(AppStringsScope oldWidget) =>
      oldWidget.strings._sw != strings._sw;
}

/// Typed UI copy for English + Kiswahili.
class AppStrings {
  const AppStrings._(this._sw);
  final bool _sw;

  factory AppStrings.of(BuildContext context) => AppStringsScope.of(context);

  /// Safe outside [build] (callbacks, async methods) — does not listen.
  factory AppStrings.read(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<AppStringsScope>();
    if (scope != null) return scope.strings;
    return AppStrings.fromLocale(context.read<LocaleCubit>().state);
  }

  factory AppStrings.fromLocale(Locale locale) =>
      AppStrings._(locale.languageCode == 'sw');

  String _t(String en, String sw) => _sw ? sw : en;

  // ── App ────────────────────────────────────────────────────────────
  String get appName => 'POS App';
  String get appTagline =>
      _t('Point of Sale System', 'Mfumo wa Mauzo (POS)');
  String get language => _t('Language', 'Lugha');
  String get english => _t('English', 'Kiingereza');
  String get swahili => _t('Swahili', 'Kiswahili');
  String get languageHint => _t(
        'Choose app display language',
        'Chagua lugha ya kuonesha programu',
      );
  String get theme => _t('Theme', 'Mandhari');
  String get themeHint => _t(
        'Choose app color style',
        'Chagua mtindo wa rangi wa programu',
      );
  String get themeClassic => _t('Classic', 'Asili');
  String get themeWarm => _t('Warm', 'Joto');
  String get themeGrove => _t('Grove', 'Kijani');

  // ── Auth / Login ───────────────────────────────────────────────────
  String get signIn => _t('Sign In', 'Ingia');
  String get signInSubtitle => _t(
        'Sign in to continue to your dashboard',
        'Ingia ili kuendelea kwenye dashibodi yako',
      );
  String get emailAddress => _t('Email Address', 'Barua pepe');
  String get username => _t('Username', 'Jina la mtumiaji');
  String get password => _t('Password', 'Nenosiri');
  String get forgotPassword => _t('Forgot Password?', 'Umesahau nenosiri?');
  String get welcomeBack => _t('Welcome back', 'Karibu tena');

  // ── Navigation ─────────────────────────────────────────────────────
  String get dashboard => _t('Dashboard', 'Dashibodi');
  String get pos => 'POS';
  String get inventory => _t('Inventory', 'Hifadhi');
  String get purchases => _t('Purchases', 'Manunuzi');
  String get suppliers => _t('Suppliers', 'Wasambazaji');
  String get reports => _t('Reports', 'Ripoti');
  String get sales => _t('Sales', 'Mauzo');
  String get shops => _t('Shops', 'Maduka');
  String get users => _t('Users', 'Watumiaji');
  String get customers => _t('Customers', 'Wateja');
  String get staff => _t('Staff', 'Wafanyakazi');
  String get transactions => _t('Transactions', 'Miamala');
  String get settings => _t('Settings', 'Mipangilio');
  String get more => _t('More', 'Zaidi');
  String get moreMenuTitle => _t('Menu', 'Menyu');
  String get moreMenuSubtitle =>
      _t('Manage your shop tools', 'Dhibiti zana za duka lako');
  String get quickAccess => _t('QUICK ACCESS', 'UFIKIAJI WA HARAKA');
  String get preferences => _t('PREFERENCES', 'MAPENDEKEZO');
  String get home => _t('Home', 'Nyumbani');

  // ── Common actions ─────────────────────────────────────────────────
  String get cancel => _t('Cancel', 'Ghairi');
  String get save => _t('Save', 'Hifadhi');
  String get create => _t('Create', 'Unda');
  String get edit => _t('Edit', 'Hariri');
  String get delete => _t('Delete', 'Futa');
  String get search => _t('Search', 'Tafuta');
  String get searchCustomersHint =>
      _t('Search name, phone, email…', 'Tafuta jina, simu, barua pepe…');
  String get setDiscount => _t('Set discount', 'Weka punguzo');
  String get autoLoyalty =>
      _t('Auto loyalty from activity', 'Uaminifu kiotomatiki kutoka shughuli');
  String get debtLabel => _t('Debt', 'Deni');
  String get off => _t('off', 'punguzo');
  String get confirm => _t('Confirm', 'Thibitisha');
  String get close => _t('Close', 'Funga');
  String get refresh => _t('Refresh', 'Onyesha upya');
  String get loading => _t('Loading…', 'Inapakia…');
  String get retry => _t('Retry', 'Jaribu tena');
  String get success => _t('Success', 'Imefanikiwa');
  String get error => _t('Error', 'Hitilafu');
  String get optional => _t('Optional', 'Si lazima');
  String get logout => _t('Sign Out', 'Toka');
  String get account => _t('Account', 'Akaunti');
  String get appSection => _t('App', 'Programu');

  // ── Settings ───────────────────────────────────────────────────────
  String get changePassword => _t('Change Password', 'Badilisha nenosiri');
  String get changePasswordHint =>
      _t('Update your login credentials', 'Sasisha taarifa za kuingia');
  String get aboutApp => _t('About POS App', 'Kuhusu POS App');
  String get shopSettings => _t('Shop settings', 'Mipangilio ya duka');
  String get shopSettingsOwnerOnly => _t(
        'Store settings are only available for shop owners.',
        'Mipangilio ya duka inapatikana kwa wamiliki wa maduka pekee.',
      );
  String get shopTab => _t('Shop', 'Duka');
  String get planTab => _t('Plan', 'Mpango');
  String get appearance => _t('Appearance', 'Muonekano');
  String get shopInfo => _t('Shop Info', 'Taarifa za Duka');
  String get shopNameLabel => _t('Shop name', 'Jina la duka');
  String get currencyLabel => _t('Currency', 'Sarafu');
  String get shopSaved => _t('Shop info saved', 'Taarifa za duka zimehifadhiwa');
  String get noShopProfile =>
      _t('No shop profile found.', 'Hakuna wasifu wa duka.');
  String get signOutConfirm =>
      _t('Sign out of POS App?', 'Toka kwenye POS App?');
  String get addBranch => _t('Add Branch', 'Ongeza Tawi');
  String get editBranch => _t('Edit Branch', 'Hariri Tawi');
  String get branchNameLabel => _t('Branch name', 'Jina la tawi');
  String get branchFormHint => _t(
        'Cashiers sign in against this location',
        'Wauzaji wataingia kwenye eneo hili',
      );
  String get updateBranch => _t('Update Branch', 'Sasisha Tawi');
  String get branchAdded => _t('Branch added', 'Tawi limeongezwa');
  String get branchUpdated => _t('Branch updated', 'Tawi limesasishwa');
  String get branchDeleted => _t('Branch deleted', 'Tawi limefutwa');
  String get deleteBranch => _t('Delete Branch', 'Futa Tawi');
  String deleteBranchConfirm(String name) => _t(
        'Delete "$name"? Cashiers must be reassigned first.',
        'Futa "$name"? Wauzaji lazima wahamishwe kwanza.',
      );
  String branchCountLabel(int n) => _sw
      ? (n == 1 ? 'Tawi 1' : 'Matawi $n')
      : (n == 1 ? '1 branch' : '$n branches');
  String cashiersAtBranch(int n) => _sw
      ? (n == 1 ? 'Muuzaji 1' : 'Wauzaji $n')
      : (n == 1 ? '1 cashier' : '$n cashiers');
  String get noBranchesHint => _t(
        'Add a branch so cashiers can be assigned a location.',
        'Ongeza tawi ili wauzaji waweze kupangiwa eneo.',
      );
  String get noAdditionalInfo =>
      _t('No additional info', 'Hakuna taarifa zaidi');
  String get currentPlan => _t('Current Plan', 'Mpango wa Sasa');
  String get nextPaymentDue =>
      _t('Next Payment Due', 'Malipo Yanayofuata');
  String get paymentHistory =>
      _t('Payment History', 'Historia ya Malipo');
  String get noPaymentHistory =>
      _t('No payment history yet', 'Bado hakuna historia ya malipo');
  String get noActiveSubscription => _t(
        'No active subscription. Contact your platform administrator.',
        'Hakuna usajili hai. Wasiliana na msimamizi.',
      );
  String get savingEllipsis => _t('Saving…', 'Inahifadhi…');

  // ── Customers / Debts ──────────────────────────────────────────────
  String get customersAndCredit =>
      _t('Customers & Credit book', 'Wateja na Deni');
  String get purchasers => _t('Purchasers', 'Wanunuzi');
  String get debts => _t('Debts', 'Madeni');
  String get addPurchaser => _t('Add purchaser', 'Ongeza mnunuzi');
  String get recordDebt => _t('Record debt', 'Rekodi deni');
  String get newCustomer => _t('New customer', 'Mteja mpya');
  String get editCustomer => _t('Edit customer', 'Hariri mteja');
  String get customerName => _t('Customer name', 'Jina la mteja');
  String get phone => _t('Phone', 'Simu');
  String get email => _t('Email', 'Barua pepe');
  String get address => _t('Address', 'Anwani');
  String get discountPercent => _t('Discount %', 'Punguzo %');
  String get loyaltyTier => _t('Loyalty tier', 'Kiwango cha uaminifu');
  String get openDebts => _t('Open debts', 'Madeni yaliyo wazi');
  String get toCollect => _t('To collect', 'Ya kukusanya');
  String get collect => _t('Collect', 'Kusanya');
  String get amountPaid => _t('Amount paid', 'Kiasi kilicholipwa');
  String get amountOwed => _t('Amount owed (TZS)', 'Deni (TZS)');
  String get whatFor => _t('What for? (optional)', 'Kwa nini? (si lazima)');
  String get saveCreditBook =>
      _t('Save to credit book', 'Hifadhi kwenye kitabu cha deni');
  String get recordDebtTitle =>
      _t('Record debt (credit book)', 'Rekodi deni (kitabu cha mkopo)');
  String get recordDebtHint => _t(
        'Like writing in a notebook: who took goods, how much they owe, and what for.',
        'Kama kuandika kwenye daftari: nani alichukua bidhaa, anadaiwa kiasi gani, na kwa nini.',
      );
  String get existingBuyer => _t('Existing buyer', 'Mnunuzi aliyepo');
  String get newName => _t('New name', 'Jina jipya');
  String get whoOwes => _t('Who owes?', 'Nani anadaiwa?');
  String get noPurchasersYet => _t(
        'No purchasers yet. They appear when people buy (or when you add them). Use Debts as your credit book instead of paper/Excel.',
        'Bado hakuna wanunuzi. Wataonekana wanaponunua (au unapowaongeza). Tumia Madeni kama kitabu cha mkopo badala ya karatasi/Excel.',
      );
  String get creditBookEmpty => _t(
        'Credit book is empty. Tap “Record debt” when someone takes goods to pay later — then Collect when they pay.',
        'Kitabu cha deni ni tupu. Gusa “Rekodi deni” mtu anapochukua bidhaa kulipa baadaye — kisha Kusanya anapolipa.',
      );
  String get purchasesWord => _t('purchases', 'manunuzi');
  String get mostActiveLoyalty =>
      _t('Most active · loyalty discounts', 'Hai zaidi · punguzo la uaminifu');

  // ── POS / Checkout ─────────────────────────────────────────────────
  String get pointOfSale => _t('Point of Sale', 'Sehemu ya Mauzo');
  String get tapProductToCart =>
      _t('Tap a product to add it to cart', 'Gusa bidhaa kuongeza kwenye kikapu');
  String get h10ScannerActive => _t(
        'H10S scanner active — scan to add items',
        'Skana ya H10S inatumika — skani kuongeza bidhaa',
      );
  String get salesHistory => _t('Sales history', 'Historia ya mauzo');
  String get scanBarcode => _t('Scan barcode', 'Skani msimbo');
  String get hardwareScanner => _t('Hardware scanner', 'Skana ya kifaa');
  String get add => _t('Add', 'Ongeza');
  String get searchProductsHint => _t(
        'Search by product name or barcode…',
        'Tafuta kwa jina la bidhaa au msimbo…',
      );
  String get searchProductsShort =>
      _t('Search products…', 'Tafuta bidhaa…');
  String get loadingProducts =>
      _t('Loading products…', 'Inapakia bidhaa…');
  String get failedLoadProducts =>
      _t('Failed to load products', 'Imeshindwa kupakia bidhaa');
  String get checkConnection => _t(
        'Check your connection and try again',
        'Angalia muunganisho wako kisha jaribu tena',
      );
  String get noProductsFound =>
      _t('No products found', 'Hakuna bidhaa zilizopatikana');
  String get tryDifferentName => _t(
        'Try a different name or barcode',
        'Jaribu jina au msimbo tofauti',
      );
  String get outOfStock => _t('Out of Stock', 'Imeisha');
  String get outOfStockLower => _t('Out of stock', 'Imeisha');
  String inStock(int n) =>
      _t('$n in stock', '$n zinapatikana');
  String get cart => _t('Cart', 'Kikapu');
  String get clearAll => _t('Clear all', 'Futa zote');
  String get cartEmpty => _t('Your cart is empty', 'Kikapu chako ni tupu');
  String get addProductsFromList =>
      _t('Add products from the list', 'Ongeza bidhaa kutoka kwenye orodha');
  String get processingPayment =>
      _t('Processing payment…', 'Inachakata malipo…');
  String itemsInCart(int n) => _sw
      ? (n == 1 ? 'Bidhaa 1 kwenye kikapu' : 'Bidhaa $n kwenye kikapu')
      : (n == 1 ? '1 item in cart' : '$n items in cart');
  String get tapReviewCheckout =>
      _t('Tap to review & checkout', 'Gusa kuangalia na kulipa');
  String get inclVat => _t('incl. VAT', 'ikiwa ni VAT');
  String get subtotal => _t('Subtotal', 'Jumla ndogo');
  String get totalAmount => _t('Total amount', 'Jumla ya kiasi');
  String get includingAllTaxes =>
      _t('Including all taxes', 'Ikiwa ni kodi zote');
  String get proceedToCheckout =>
      _t('Proceed to Checkout', 'Endelea na Malipo');
  String get processing => _t('Processing…', 'Inachakata…');
  String get addProduct => _t('Add Product', 'Ongeza Bidhaa');
  String get selectProductToCart => _t(
        'Select a product to add to cart',
        'Chagua bidhaa kuongeza kwenye kikapu',
      );
  String get inCart => _t('In cart', 'Kwenye kikapu');
  String get selectAProduct => _t('Select a product', 'Chagua bidhaa');
  String get addToCart => _t('Add to Cart', 'Ongeza kwenye Kikapu');
  String get barcodeNotFound =>
      _t('Barcode not found', 'Msimbo haujapatikana');
  String get productsStillLoading =>
      _t('Products still loading…', 'Bidhaa bado zinapakia…');
  String get maxStockReached =>
      _t('Max stock reached for', 'Hifadhi imeisha kwa');
  String get insufficientStock =>
      _t('Insufficient stock', 'Hifadhi haitoshi');
  String get enterQuantity => _t('Enter quantity', 'Weka idadi');
  String get quantityLabel => _t('Quantity', 'Idadi');
  String get setQuantity => _t('Set quantity', 'Weka idadi');
  String get addQuantity => _t('Add quantity', 'Ongeza idadi');
  String get quantityHint =>
      _t('Type how many to add', 'Andika idadi ya kuongeza');
  String get qtyTapHint => _t(
        'Long-press a product to type quantity',
        'Bonyeza muda mrefu kuandika idadi',
      );
  String get authErrorLogin => _t(
        'Authentication error. Please log in again.',
        'Hitilafu ya uthibitishaji. Tafadhali ingia tena.',
      );

  String get checkout => _t('Checkout', 'Malipo');
  String get cartTotal => _t('Cart total', 'Jumla ya kikapu');
  String get amountDue => _t('Amount Due', 'Kiasi kinachotakiwa');
  String get loyaltyOff => _t('Loyalty', 'Uaminifu');
  String get discountSection => _t('Discount', 'Punguzo');
  String get discountSectionHint => _t(
        'Use loyalty, type a %, or enter a fixed TZS amount',
        'Tumia uaminifu, andika %, au weka kiasi cha TZS',
      );
  String get discountNone => _t('None', 'Hakuna');
  String get discountByPercent => _t('Percent %', 'Asilimia %');
  String get discountByAmount => _t('Amount TZS', 'Kiasi TZS');
  String get manualDiscount => _t('Manual discount', 'Punguzo la mkono');
  String get manualDiscountAmount =>
      _t('Discount amount (TZS)', 'Kiasi cha punguzo (TZS)');
  String get enterValidDiscountPercent => _t(
        'Enter a discount percent between 0 and 100',
        'Weka asilimia ya punguzo kati ya 0 na 100',
      );
  String get enterValidDiscountAmount => _t(
        'Enter a valid discount amount',
        'Weka kiasi sahihi cha punguzo',
      );
  String get purchaser => _t('Purchaser', 'Mnunuzi');
  String get selectPurchaserHint => _t(
        'Select a saved customer to confirm identity and apply their loyalty discount. Or type a walk-in name.',
        'Chagua mteja aliyehifadhiwa ili kuthibitisha na kutumia punguzo lake. Au andika jina la mteja wa kawaida.',
      );
  String get selectSavedPurchaser =>
      _t('Select saved purchaser', 'Chagua mnunuzi aliyehifadhiwa');
  String get changePurchaser => _t('Change purchaser', 'Badilisha mnunuzi');
  String get loadingCustomers => _t('Loading customers…', 'Inapakia wateja…');
  String get walkInName =>
      _t('Customer name (walk-in OK)', 'Jina la mteja (mgeni anaweza)');
  String get paymentMethod => _t('Payment method', 'Njia ya malipo');
  String get cash => _t('Cash', 'Fedha taslimu');
  String get card => _t('Card', 'Kadi');
  String get mobileMoney => _t('Mobile Money', 'Pesa za simu');
  String get creditDebtBook =>
      _t('Credit (debt book)', 'Mkopo (kitabu cha deni)');
  String get cashDesc =>
      _t('Physical currency payment', 'Malipo kwa fedha taslimu');
  String get cardDesc => _t('Credit or debit card', 'Kadi ya mkopo au debiti');
  String get mobileDesc =>
      _t('M-Pesa, Airtel Money, etc.', 'M-Pesa, Airtel Money, n.k.');
  String get creditDesc => _t(
        'Pay later — recorded as open debt',
        'Lipa baadaye — itawekwa kama deni lililo wazi',
      );
  String get amountTendered => _t('Amount tendered', 'Kiasi kilichotolewa');
  String get selectMethod => _t('Select method', 'Chagua njia');
  String get confirmPayment => _t('Confirm Payment', 'Thibitisha malipo');
  String get confirmWithAmount => _t('Confirm', 'Thibitisha');
  String get creditNeedsCustomer => _t(
        'Credit sale needs a customer — who owes the shop?',
        'Uuzaji wa mkopo unahitaji mteja — nani anadaiwa na duka?',
      );
  String get addItemsFirst =>
      _t('Add items to cart first', 'Weka bidhaa kwenye kikapu kwanza');
  String get noDiscountSet => _t('No discount set', 'Hakuna punguzo');
  String get loyaltyDiscount =>
      _t('loyalty discount', 'punguzo la uaminifu');

  String get nameRequired => _t('Name *', 'Jina *');
  String get customerNameRequired =>
      _t('Customer name *', 'Jina la mteja *');
  String get amountOwedRequired =>
      _t('Amount owed (TZS) *', 'Deni (TZS) *');
  String get discountHelper => _t(
        'Manual loyalty discount for this customer',
        'Punguzo la uaminifu kwa mteja huyu',
      );
  String get customerNameHint =>
      _t('e.g. Mama Asha', 'mf. Mama Asha');
  String get whatForHint => _t(
        'e.g. 2 sacks flour, taken Monday',
        'mf. magunia 2 ya unga, iliyochukuliwa Jumatatu',
      );
  String get note => _t('Note', 'Maelezo');
  String get balance => _t('Balance', 'Salio');
  String get collectFrom => _t('Collect from', 'Kusanya kutoka kwa');
  String get record => _t('Record', 'Rekodi');
  String get tierStandard => _t('Standard', 'Kawaida');
  String get tierBronze => _t('Bronze (active)', 'Shaba (hai)');
  String get tierSilver => _t('Silver', 'Fedha');
  String get tierGold => _t('Gold', 'Dhahabu');
  String get customersCount => _t('customers', 'wateja');

  // ── Inventory / Products ───────────────────────────────────────────
  String inventorySubtitle(int products, int units) => _t(
        '$products products · $units units',
        'Bidhaa $products · vipimo $units',
      );
  String get loadingInventory =>
      _t('Loading inventory...', 'Inapakia hifadhi...');
  String get searchInventoryHint => _t(
        'Search name, barcode, category…',
        'Tafuta jina, msimbo, aina…',
      );
  String get allProducts => _t('All Products', 'Bidhaa Zote');
  String get allCategories => _t('All categories', 'Aina zote');
  String get lowStock => _t('Low Stock', 'Hifadhi Ndogo');
  String get noProductsYet => _t('No products yet', 'Bado hakuna bidhaa');
  String noResultsFor(String q) =>
      _t('No results for "$q"', 'Hakuna matokeo ya "$q"');
  String get addFirstProduct => _t(
        'Add your first product to get started',
        'Ongeza bidhaa yako ya kwanza ili kuanza',
      );
  String get addNewProduct => _t('Add New Product', 'Ongeza Bidhaa Mpya');
  String get editProduct => _t('Edit Product', 'Hariri Bidhaa');
  String get productCol => _t('Product', 'Bidhaa');
  String get barcodeCol => _t('Barcode', 'Msimbo');
  String get barcodeOptional =>
      _t('Barcode (optional)', 'Msimbo (si lazima)');
  String get categoryCol => _t('Category', 'Aina');
  String get categories => _t('Categories', 'Aina');
  String get productsTab => _t('Products', 'Bidhaa');
  String get addNewCategory => _t('Add New Category', 'Ongeza Aina Mpya');
  String get categoryNameHint =>
      _t('e.g. Beverages, Soft drinks…', 'mf. Vinywaji, Soft drinks…');
  String get parentCategoryOptional =>
      _t('Parent category (optional)', 'Aina kuu (si lazima)');
  String get topLevelCategory =>
      _t('Top-level category', 'Aina kuu');
  String get subcategoryHint => _t(
        'Leave parent empty for a main category, or pick one to add a subcategory.',
        'Acha aina kuu wazi kwa aina mpya, au chagua ili kuongeza aina ndogo.',
      );
  String get deleteSubcategoriesFirst => _t(
        'Delete subcategories first',
        'Futa aina ndogo kwanza',
      );
  String subcategoriesCount(int n) => _sw
      ? (n == 1 ? 'aina ndogo 1' : 'aina ndogo $n')
      : (n == 1 ? '1 subcategory' : '$n subcategories');
  String get yourCategories => _t('Your Categories', 'Aina Zako');
  String get noCategoriesYet =>
      _t('No categories yet.', 'Hakuna aina bado.');
  String get addFirstCategory =>
      _t('Add your first category above.', 'Ongeza aina yako ya kwanza hapo juu.');
  String get categoryAdded => _t('Category added', 'Aina imeongezwa');
  String get categoryDeleted => _t('Category removed', 'Aina imeondolewa');
  String get deleteCategory => _t('Delete category', 'Futa aina');
  String get selectCategory => _t('Select category…', 'Chagua aina…');
  String get categoryRequired =>
      _t('Category is required', 'Aina inahitajika');
  String get addCategoriesFirst => _t(
        'No saved categories — add some in the Categories tab',
        'Hakuna aina zilizohifadhiwa — ongeza kwenye kichupo cha Aina',
      );
  String productsCount(int n) =>
      _t('$n products', 'Bidhaa $n');
  String get unsavedCategoriesHint => _t(
        'Used in products but not saved yet (tap to save):',
        'Zinatumika kwenye bidhaa lakini hazijahifadhiwa (gusa kuhifadhi):',
      );
  String get priceCol => _t('Price', 'Bei');
  String get stockCol => _t('Stock', 'Hifadhi');
  String get actionsCol => _t('Actions', 'Vitendo');
  String get generalCategory => _t('General', 'Jumla');
  String get productNameRequired =>
      _t('Product Name *', 'Jina la Bidhaa *');
  String get productPhoto => _t('Product photo', 'Picha ya bidhaa');
  String get choosePhoto => _t('Choose photo', 'Chagua picha');
  String get takePhoto => _t('Take photo', 'Piga picha');
  String get productNameHint =>
      _t('e.g. Coca Cola 500ml', 'mf. Coca Cola 500ml');
  String get barcodeHint =>
      _t('e.g. 5449000000996', 'mf. 5449000000996');
  String get barcodeHintOptional => _t(
        'Leave blank if product has no barcode',
        'Acha tupu ikiwa bidhaa haina msimbo',
      );
  String get categoryHint =>
      _t('e.g. Beverages', 'mf. Vinywaji');
  String get priceTzsRequired =>
      _t('Price (TZS) *', 'Bei (TZS) *');
  String get enterValidPrice =>
      _t('Enter a valid price', 'Weka bei sahihi');
  String get stockQuantity =>
      _t('Stock Quantity', 'Idadi ya Hifadhi');
  String get lowStockAlertAt =>
      _t('Low Stock Alert At', 'Onyo la Hifadhi Ndogo');
  String get requiredField => _t('Required', 'Inahitajika');
  String get saveChanges => _t('Save Changes', 'Hifadhi Mabadiliko');
  String get deleteProduct => _t('Delete Product', 'Futa Bidhaa');
  String get deleteProductConfirm => _t(
        'Are you sure you want to delete ',
        'Una uhakika unataka kufuta ',
      );
  String get deleteCannotUndo => _t(
        '? This action cannot be undone.',
        '? Kitendo hiki hakiwezi kutenduliwa.',
      );
  String get cannotDeleteMissingId => _t(
        'Cannot delete: missing product id',
        'Haiwezi kufutwa: kitambulisho cha bidhaa hakipo',
      );

  // ── Reports ────────────────────────────────────────────────────────
  String get reportsSubtitle => _t(
        'Track performance across all time periods',
        'Fuatilia utendaji katika vipindi vyote',
      );
  String get periodDaily => _t('Daily', 'Leo');
  String get periodWeekly => _t('Weekly', 'Wiki');
  String get periodMonthly => _t('Monthly', 'Mwezi');
  String get totalRevenue => _t('Total Revenue', 'Jumla ya Mapato');
  String get avgTransaction =>
      _t('Avg. Transaction', 'Wastani wa Muamala');
  String get hourlySales => _t('Hourly Sales', 'Mauzo kwa Saa');
  String get salesTrend => _t('Sales Trend', 'Mwelekeo wa Mauzo');
  String get noSalesDataPeriod => _t(
        'No sales data for this period',
        'Hakuna data ya mauzo kwa kipindi hiki',
      );
  String get paymentMethods =>
      _t('Payment Methods', 'Njia za Malipo');
  String get noPaymentData =>
      _t('No payment data', 'Hakuna data ya malipo');
  String get transactionHistory =>
      _t('Transaction History', 'Historia ya Miamala');
  String transactionsCount(int n) =>
      _t('$n transactions', 'Miamala $n');
  String get noTransactionsPeriod => _t(
        'No transactions for this period',
        'Hakuna miamala kwa kipindi hiki',
      );
  String itemsCount(int n) =>
      _sw ? (n == 1 ? 'Bidhaa 1' : 'Bidhaa $n') : (n == 1 ? '1 item' : '$n items');
  String get downloadPdf => _t('Download PDF', 'Pakua PDF');
  String get shareReportPdf =>
      _t('Share / save report PDF', 'Shiriki / hifadhi ripoti PDF');
  String get generatingPdf =>
      _t('Generating PDF…', 'Inatengeneza PDF…');
  String get pdfReady =>
      _t('Report PDF ready', 'PDF ya ripoti iko tayari');
  String get pdfFailed =>
      _t('Could not create PDF', 'Imeshindwa kutengeneza PDF');
  String get reportPeriod => _t('Period', 'Kipindi');
  String get generatedAt => _t('Generated', 'Imetengenezwa');
  String get receiptNo => _t('Receipt', 'Risiti');
  String get dateTime => _t('Date / Time', 'Tarehe / Saa');
  String get amount => _t('Amount', 'Kiasi');
  String get method => _t('Method', 'Njia');
  String get summary => _t('Summary', 'Muhtasari');
  String get otherPayment => _t('Other', 'Nyingine');

  // ── Home / marketing ───────────────────────────────────────────────
  String get getStarted => _t('Get started', 'Anza sasa');
  String get openPos => _t('Open POS', 'Fungua POS');

  // ── Dashboard ──────────────────────────────────────────────────────
  String get ownerDashboard =>
      _t('Owner Dashboard', 'Dashibodi ya Mmiliki');
  String get overview => _t('Overview', 'Muhtasari');
  String get analytics => _t('Analytics', 'Takwimu');
  String get storeOverviewToday => _t(
        "Here's your store overview for today",
        'Hii ni muhtasari wa duka lako leo',
      );
  String get userFallback => _t('User', 'Mtumiaji');
  String get cashierFallback => _t('Cashier', 'Muuzaji');
  String goodGreeting(String name) {
    final h = DateTime.now().hour;
    if (h < 12) {
      return _t('Good morning, $name', 'Habari za asubuhi, $name');
    }
    if (h < 18) {
      return _t('Good afternoon, $name', 'Habari za mchana, $name');
    }
    return _t('Good evening, $name', 'Habari za jioni, $name');
  }

  String hiName(String name) => _t('Hi, $name 👋', 'Habari, $name 👋');
  String welcomeUser(String name) => _t('Welcome, $name', 'Karibu, $name');
  String get contactAdminForRole => _t(
        'Contact your admin to assign a role',
        'Wasiliana na msimamizi wako akupatie jukumu',
      );
  String get todaysSales => _t("Today's Sales", 'Mauzo ya Leo');
  String get todaysRevenue => _t("Today's Revenue", 'Mapato ya Leo');
  String get totalSales => _t('Total Sales', 'Jumla ya Mauzo');
  String unitsCount(int n) => _t('$n units', 'vipimo $n');
  String get allGood => _t('All good', 'Vyote vizuri');
  String get needsAttention => _t('Needs attention', 'Inahitaji uangalizi');
  String get weeklySalesOverview =>
      _t('Weekly Sales Overview', 'Mauzo ya Wiki');
  String get stockByCategory => _t('Stock by Category', 'Hifadhi kwa Aina');
  String get otherCategory => _t('Other', 'Nyingine');
  String get lowStockAlerts =>
      _t('Low Stock Alerts', 'Onyo la Hifadhi Ndogo');
  String get allProductsWellStocked => _t(
        'All products are well stocked!',
        'Bidhaa zote zina hifadhi ya kutosha!',
      );
  String leftCount(int n) => _t('$n left', 'zimesalia $n');
  String minStockLabel(int n) => _t('Min: $n', 'Kiwango: $n');
  String get recentTransactions =>
      _t('Recent Transactions', 'Miamala ya Hivi Karibuni');
  String get noSalesYetToday =>
      _t('No sales yet today.', 'Bado hakuna mauzo leo.');
  String get recentSales => _t('Recent Sales', 'Mauzo ya Hivi Karibuni');
  String get seeAll => _t('See all', 'Ona zote');
  String get noSalesRecordedYet =>
      _t('No sales recorded yet', 'Bado hakuna mauzo yaliyorekodiwa');
  String get noAnalyticsDataYet =>
      _t('No analytics data yet', 'Bado hakuna data ya takwimu');
  String get quickActions => _t('Quick Actions', 'Vitendo vya Haraka');
  String get businessOverview =>
      _t('Business Overview', 'Muhtasari wa Biashara');
  String salesTodayTotal(int today, int total) => _t(
        '$today sales today · $total total',
        'Mauzo $today leo · jumla $total',
      );
  String get totalTransactions =>
      _t('Total Transactions', 'Jumla ya Miamala');
  String get avgOrderValue => _t('Avg Order Value', 'Wastani wa Oda');
  String get largestSale => _t('Largest Sale', 'Uuzaji Mkubwa');
  String revenueLastNSales(int n) =>
      _t('Revenue — Last $n Sales', 'Mapato — Mauzo $n ya mwisho');
  String get somethingWentWrong =>
      _t('Something went wrong', 'Hitilafu imetokea');
  String get authRequired =>
      _t('Authentication Required', 'Uthibitishaji Unahitajika');
  String get pleaseLogInDashboard => _t(
        'Please log in to access the dashboard',
        'Tafadhali ingia ili kufungua dashibodi',
      );
  String get goToLogin => _t('Go to Login', 'Nenda Kuingia');
  String saleNumber(String id) => _t('Sale #$id', 'Mauzo #$id');
  String get allCompletedTransactions =>
      _t('All completed transactions', 'Miamala yote iliyokamilika');
  String get noSalesYet => _t('No sales yet', 'Bado hakuna mauzo');
  String get completedPosWillAppear => _t(
        'Completed POS sales will appear here',
        'Mauzo yaliyokamilika yataonekana hapa',
      );
  String get transactionsSubtitle =>
      _t('Completed sales & payments', 'Mauzo na malipo yaliyokamilika');
  String get manageYourTeam => _t('Manage your team', 'Simamia timu yako');
  String get addCashier => _t('Add Cashier', 'Ongeza Muuzaji');
  String get editCashier => _t('Edit Cashier', 'Hariri Muuzaji');
  String get cashierFormHint => _t(
        'Create a POS login for this location',
        'Unda akaunti ya POS kwa eneo hili',
      );
  String get teamMembers => _t('Team Members', 'Wanachama wa Timu');
  String get fullName => _t('Full Name', 'Jina Kamili');
  String get passwordMinHint =>
      _t('At least 8 characters', 'Angalau herufi 8');
  String get branchLabel => _t('Branch', 'Tawi');
  String get selectBranch => _t('Select branch', 'Chagua tawi');
  String get assignToBranch =>
      _t('Assign to branch', 'Weka kwenye tawi');
  String get assignedLocation =>
      _t('Assigned location', 'Eneo alilopangiwa');
  String get loadingBranches =>
      _t('Loading branches…', 'Inapakia matawi…');
  String get noBranchesYet => _t('No branches yet', 'Bado hakuna matawi');
  String get addBranchInSettings => _t(
        'Add a branch in Settings before inviting cashiers.',
        'Ongeza tawi katika Mipangilio kabla ya kuongeza wauzaji.',
      );
  String get selectBranchFirst =>
      _t('Select a branch first', 'Chagua tawi kwanza');
  String get staffAdded => _t('Cashier added', 'Muuzaji ameongezwa');
  String get staffUpdated => _t('Cashier updated', 'Muuzaji amesasishwa');
  String get loadingStaff => _t('Loading staff…', 'Inapakia wafanyakazi…');
  String get noStaffYet =>
      _t('No cashiers yet', 'Bado hakuna wauzaji');
  String get tapToAddStaff => _t(
        'Add a cashier so they can sign in at the till.',
        'Ongeza muuzaji ili aweze kuingia kwenye POS.',
      );
  String get cashiersLabel => _t('Cashiers', 'Wauzaji');
  String get branchesLabel => _t('Branches', 'Matawi');
  String get totalLabel => _t('Total', 'Jumla');
  String get unableToLoadStaff =>
      _t('Unable to load staff', 'Imeshindwa kupakia wafanyakazi');
  String get checkConnectionRetry => _t(
        'Check your connection and try again.',
        'Angalia muunganisho wako kisha jaribu tena.',
      );
  String get searchStaffHint =>
      _t('Search staff…', 'Tafuta wafanyakazi…');
  String get removeStaffMember =>
      _t('Remove Staff Member', 'Ondoa Mfanyakazi');
  String get staffRemoved =>
      _t('Staff member removed', 'Mfanyakazi ameondolewa');
  String removeStaffConfirm(String name) => _t(
        'Are you sure you want to remove $name? This action cannot be undone.',
        'Una uhakika unataka kumwondoa $name? Kitendo hiki hakiwezi kutenduliwa.',
      );
  String get remove => _t('Remove', 'Ondoa');

  // ── Purchases / suppliers ───────────────────────────────────────────
  String get purchasesSubtitle => _t(
        'Suppliers, stock receiving & costs',
        'Wasambazaji, kupokea bidhaa na gharama',
      );
  String get purchasesTab => _t('Purchases', 'Manunuzi');
  String get suppliersTab => _t('Suppliers', 'Wasambazaji');
  String get newPurchase => _t('New purchase', 'Ununuzi mpya');
  String get editPurchase => _t('Edit purchase', 'Hariri ununuzi');
  String get purchaseDetail => _t('Purchase detail', 'Maelezo ya ununuzi');
  String get addSupplier => _t('Add supplier', 'Ongeza msambazaji');
  String get editSupplier => _t('Edit supplier', 'Hariri msambazaji');
  String get supplierName => _t('Supplier name', 'Jina la msambazaji');
  String get supplierPhone => _t('Phone', 'Simu');
  String get supplierEmail => _t('Email', 'Barua pepe');
  String get supplierAddress => _t('Address', 'Anwani');
  String get supplierNotes => _t('Notes', 'Maelezo');
  String get noSuppliersYet =>
      _t('No suppliers yet', 'Bado hakuna wasambazaji');
  String get addFirstSupplier => _t(
        'Add suppliers so you can track who you buy from.',
        'Ongeza wasambazaji ili ufuatilie unaponunua kutoka kwao.',
      );
  String get noPurchasesYet =>
      _t('No purchases yet', 'Bado hakuna manunuzi');
  String get addFirstPurchase => _t(
        'Record a purchase draft, then receive goods to update stock.',
        'Andika rasimu ya ununuzi, kisha pokea bidhaa ili kusasisha hifadhi.',
      );
  String get searchPurchasesHint => _t(
        'Search reference or supplier…',
        'Tafuta nambari au msambazaji…',
      );
  String get searchSuppliersHint =>
      _t('Search suppliers…', 'Tafuta wasambazaji…');
  String get statusAll => _t('All', 'Zote');
  String get statusDraft => _t('Draft', 'Rasimu');
  String get statusReceived => _t('Received', 'Imepokelewa');
  String get statusCancelled => _t('Cancelled', 'Imeghairiwa');
  String get saveDraft => _t('Save draft', 'Hifadhi rasimu');
  String get saveAndReceive =>
      _t('Save & receive', 'Hifadhi na pokea');
  String get receiveGoods => _t('Receive goods', 'Pokea bidhaa');
  String get cancelPurchase => _t('Cancel draft', 'Ghairi rasimu');
  String get receiveConfirmTitle =>
      _t('Receive this purchase?', 'Pokea ununuzi huu?');
  String get receiveConfirmBody => _t(
        'Stock will increase and product cost will update to the unit costs on this purchase.',
        'Hifadhi itaongezeka na gharama ya bidhaa itasasishwa kulingana na gharama za ununuzi huu.',
      );
  String get cancelConfirmTitle =>
      _t('Cancel this draft?', 'Ghairi rasimu hii?');
  String get cancelConfirmBody => _t(
        'Cancelled drafts do not change stock. You can create a new purchase later.',
        'Rasimu zilizoghairiwa hazibadilishi hifadhi. Unaweza kuunda ununuzi mpya baadaye.',
      );
  String get purchaseReference =>
      _t('Invoice / reference', 'Ankara / rejea');
  String get purchaseNotes => _t('Notes', 'Maelezo');
  String get purchaseDate => _t('Purchase date', 'Tarehe ya ununuzi');
  String get selectSupplier =>
      _t('Select supplier', 'Chagua msambazaji');
  String get noSupplierOptional =>
      _t('No supplier (optional)', 'Hakuna msambazaji (si lazima)');
  String get addLineItem => _t('Add product', 'Ongeza bidhaa');
  String get unitCost => _t('Unit cost', 'Gharama kwa kipimo');
  String get lineTotal => _t('Line total', 'Jumla ya mstari');
  String get purchaseSubtotal => _t('Subtotal', 'Jumla ndogo');
  String get quantityShort => _t('Qty', 'Idadi');
  String get draftsOpen => _t('Open drafts', 'Rasimu wazi');
  String get receivedThisMonth =>
      _t('Received this month', 'Zilizopokelewa mwezi huu');
  String get walkInSupplier =>
      _t('Walk-in / unspecified', 'Bila msambazaji');
  String get purchaseReceived =>
      _t('Purchase received — stock updated', 'Ununuzi umepokelewa — hifadhi imesasishwa');
  String get purchaseSaved =>
      _t('Purchase saved as draft', 'Ununuzi umehifadhiwa kama rasimu');
  String get purchaseCancelled =>
      _t('Purchase cancelled', 'Ununuzi umeghairiwa');
  String get supplierSaved =>
      _t('Supplier saved', 'Msambazaji amehifadhiwa');
  String get supplierDeleted =>
      _t('Supplier deleted', 'Msambazaji amefutwa');
  String get deleteSupplierTitle =>
      _t('Delete supplier?', 'Futa msambazaji?');
  String get deleteSupplierBody => _t(
        'Purchase history stays. This supplier will be removed from the directory.',
        'Historia ya manunuzi itabaki. Msambazaji ataondolewa kwenye orodha.',
      );
  String get pickProduct => _t('Pick a product', 'Chagua bidhaa');
  String get atLeastOneItem => _t(
        'Add at least one product line',
        'Ongeza angalau bidhaa moja',
      );
  String get costPrice => _t('Cost', 'Gharama');
  String get lastCost => _t('Last cost', 'Gharama ya mwisho');
  String get lineItems => _t('Line items', 'Bidhaa');
  String get receivedOn => _t('Received', 'Imepokelewa');

  String weekdayShort(int weekday) {
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const sw = ['Jt', 'Jn', 'Jtno', 'Alh', 'Ij', 'Jms', 'Jpl'];
    final i = ((weekday - 1) % 7 + 7) % 7;
    return _sw ? sw[i] : en[i];
  }
}

extension AppStringsX on BuildContext {
  AppStrings get t => AppStrings.of(this);
}
