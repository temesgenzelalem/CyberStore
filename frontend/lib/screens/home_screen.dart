import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/screens/product_details_screen.dart';
import 'package:frontend/screens/cart_screen.dart';
import 'package:frontend/screens/wishlist_screen.dart';
import 'package:frontend/screens/login_screen.dart';
import 'package:frontend/screens/admin/admin_dashboard.dart';
import 'package:frontend/screens/order_history_screen.dart';
import 'package:frontend/screens/settings_screen.dart';
import 'package:frontend/widgets/ai_assistant_dialog.dart';
import 'package:frontend/l10n/app_localization.dart';
import 'package:frontend/providers/app_setting_provider.dart';
import 'package:frontend/providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<ProductProvider>(context, listen: false).fetchCategories();
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final List<Widget> screens = [
      const HomeContent(),
      authProvider.isAuthenticated ? const WishlistScreen() : GuestActionPlaceholder(title: l10n?.translate('wishlist') ?? 'Wishlist'),
      authProvider.isAuthenticated ? const CartScreen() : GuestActionPlaceholder(title: l10n?.translate('cart') ?? 'Cart'),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: l10n?.translate('home') ?? 'Home'),
          BottomNavigationBarItem(icon: const Icon(Icons.favorite), label: l10n?.translate('wishlist') ?? 'Wishlist'),
          BottomNavigationBarItem(icon: const Icon(Icons.shopping_cart), label: l10n?.translate('cart') ?? 'Cart'),
          BottomNavigationBarItem(icon: const Icon(Icons.person), label: l10n?.translate('profile') ?? 'Profile'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (_) => const AiAssistantDialog()),
        child: const Icon(Icons.chat),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final settingsProvider = Provider.of<AppSettingProvider>(context);
    final l10n = AppLocalization.of(context);

    final bannerUrl = settingsProvider.settings['featured_banner_url'];
    final bannerTitle = settingsProvider.settings['featured_banner_title'] ?? l10n?.translate('app_title') ?? 'CyberStore';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await productProvider.fetchCategories();
          await productProvider.fetchProducts();
          await settingsProvider.fetchSettings();
          if (context.mounted) {
            await Provider.of<ThemeProvider>(context, listen: false).refreshFromGlobal();
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bannerUrl != null && bannerUrl != 'null')
                  Container(
                    height: 180,
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(image: NetworkImage(bannerUrl), fit: BoxFit.cover),
                    ),
                    child: Container(
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(colors: [Colors.black87, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                      ),
                      child: Text(bannerTitle, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                Text(
                  l10n?.translate('find_product') ?? 'Find your best\nproduct here',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(
                    hintText: l10n?.translate('search_hint') ?? 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  onSubmitted: (val) => productProvider.fetchProducts(search: val),
                ),
                const SizedBox(height: 30),
                Text(l10n?.translate('categories') ?? 'Categories', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: productProvider.categories.length,
                    itemBuilder: (context, index) {
                      final category = productProvider.categories[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 20.0),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                              child: Icon(Icons.category, color: Theme.of(context).primaryColor),
                            ),
                            const SizedBox(height: 5),
                            Text(category.name),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
                Text(l10n?.translate('new_arrivals') ?? 'New Arrivals', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                productProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: productProvider.products.length,
                        itemBuilder: (context, index) {
                          final product = productProvider.products[index];
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
                            ),
                            child: Card(
                              elevation: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        image: DecorationImage(
                                          image: ResizeImage(
                                            NetworkImage(product.fullImageUrl),
                                            width: 400, // Optimize RAM usage
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('${product.price} ETB', style: TextStyle(color: Theme.of(context).primaryColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GuestActionPlaceholder extends StatelessWidget {
  final String title;
  const GuestActionPlaceholder({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              l10n?.translate('locked_title').replaceAll('{title}', title) ?? 'Your $title is locked',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              l10n?.translate('locked_prompt') ?? 'Please login or register to see your items and start shopping.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              child: Text(l10n?.translate('login') ?? 'Login / Register'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final success = await Provider.of<AuthProvider>(context, listen: false).uploadAvatar(File(pickedFile.path));
      if (success && context.mounted) {
        final l10n = AppLocalization.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n?.translate('avatar_updated') ?? 'Avatar updated!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final l10n = AppLocalization.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.translate('profile') ?? 'Profile')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: () => _pickAvatar(context),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(user?.fullAvatarUrl ?? ''),
                    child: user?.avatarPath == null ? const Icon(Icons.person, size: 50) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(child: Text(user?.name ?? l10n?.translate('guest_user') ?? 'Guest User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          if (user != null) Center(child: Text(user.email)),
          const SizedBox(height: 30),
          if (user?.isAdmin ?? false)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: Text(l10n?.translate('admin_dashboard') ?? 'Admin Dashboard'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard())),
            ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n?.translate('order_history') ?? 'Order History'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(l10n?.translate('settings') ?? 'Settings'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n?.translate('logout') ?? 'Logout', style: const TextStyle(color: Colors.red)),
            onTap: () => authProvider.logout(),
          ),
        ],
      ),
    );
  }
}
