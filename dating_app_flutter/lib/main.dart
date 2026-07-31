import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/swipe_provider.dart';
import 'providers/chat_provider.dart';
import 'services/api_service.dart';
import 'services/realtime_service.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/matches_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/swipe_card.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiService = await ApiService.create();
  runApp(MyApp(apiService: apiService));
}

class MyApp extends StatelessWidget {
  final ApiService apiService;

  const MyApp({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        Provider(create: (_) => RealtimeService(usePolling: true)),
      ],
      child: MaterialApp(
        title: 'MM Cupid',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE94560)),
          useMaterial3: true,
        ),
        home: AuthGate(apiService: apiService),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  final ApiService apiService;

  const AuthGate({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (!auth.isOnboarded) {
      return const OnboardingScreen();
    }

    return ChangeNotifierProvider(
      create: (_) => SwipeProvider(apiService)..fetchProfiles(),
      child: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        children: [
          HomeTab(),
          MatchesScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFE94560),
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.local_fire_department), label: 'Discover'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: () => _swipe('dislike'),
                    icon: const Icon(Icons.close, size: 40, color: Color(0xFFE94560)),
                  ),
                  IconButton(
                    onPressed: () => _swipe('like'),
                    icon: const Icon(Icons.favorite, size: 44, color: Color(0xFF6CD153)),
                  ),
                  IconButton(
                    onPressed: () => _reload(),
                    icon: const Icon(Icons.refresh, size: 32, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildCardArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildCardArea() {
    return Consumer<SwipeProvider>(
      builder: (context, swipeProvider, _) {
        if (swipeProvider.isLoading && swipeProvider.profiles.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (swipeProvider.profiles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  swipeProvider.error ?? 'No more profiles to show',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => swipeProvider.fetchProfiles(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE94560),
                  ),
                  child: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        final profile = swipeProvider.currentUser!;
        return Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.6,
            child: SwipeCard(user: profile),
          ),
        );
      },
    );
  }

  Future<void> _swipe(String action) async {
    final swipeProvider = Provider.of<SwipeProvider>(context, listen: false);
    final apiService = Provider.of<AuthProvider>(context, listen: false).apiService;
    final realtimeService = Provider.of<RealtimeService>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final profile = swipeProvider.currentUser;

    if (profile == null) return;

    final result = await swipeProvider.swipeProfile(profile.id, action);

    if (!mounted) return;

    if (result.success) {
      if (result.isMatched) {
        _showMatchDialog(result, apiService, realtimeService, auth.user!.id);
      } else {
        swipeProvider.advance();
      }
    } else if (swipeProvider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(swipeProvider.error!), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reload() async {
    final swipeProvider = Provider.of<SwipeProvider>(context, listen: false);
    await swipeProvider.fetchProfiles();
  }

  void _showMatchDialog(SwipeResult result, ApiService apiService, RealtimeService realtimeService, int currentUserId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          ),
          child: child,
        );
      },
      pageBuilder: (context, anim, secondaryAnim) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 36,
                backgroundColor: Color(0xFFE94560),
                child: Icon(Icons.favorite_rounded, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'It\'s a Match!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.matchedUser?.name ?? 'Someone',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text(
                'You both liked each other',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Provider.of<SwipeProvider>(context, listen: false).advance();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.grey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Keep Swiping'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider(
                              create: (_) => ChatProvider(
                                apiService,
                                realtimeService,
                                currentUserId,
                              ),
                              child: ChatScreen(
                                roomId: result.roomId!,
                                matchId: result.matchId!,
                                recipientName: result.matchedUser?.name ?? '',
                                recipientPic: result.matchedUser?.profilePic,
                                currentUserId: currentUserId,
                              ),
                            ),
                          ),
                        );
                        Provider.of<SwipeProvider>(context, listen: false).advance();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE94560),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Message'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
