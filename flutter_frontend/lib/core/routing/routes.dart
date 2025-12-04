import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Deferred imports for lazy loading
import '../../features/auth/login_screen.dart' deferred as login;
import '../../features/inbox/inbox_screen.dart' deferred as inbox;
import '../../features/accounts/accounts_screen.dart' deferred as accounts;
import '../../features/calendar/calendar_screen.dart' deferred as calendar;

/// Route names for easy navigation
class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String inbox = '/inbox';
  static const String accounts = '/accounts';
  static const String calendar = '/calendar';
  static const String team = '/team';
}

/// Deferred loading wrapper widget
class DeferredWidget extends StatefulWidget {
  final Future<void> Function() libraryLoader;
  final Widget Function() childBuilder;
  
  const DeferredWidget({
    super.key,
    required this.libraryLoader,
    required this.childBuilder,
  });

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  bool _isLoaded = false;
  
  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }
  
  Future<void> _loadLibrary() async {
    await widget.libraryLoader();
    if (mounted) {
      setState(() => _isLoaded = true);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF6366F1),
          ),
        ),
      );
    }
    return widget.childBuilder();
  }
}

/// App router configuration with go_router
class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  
  static GoRouter router(Stream<User?> authStream) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppRoutes.home,
      debugLogDiagnostics: true,
      refreshListenable: GoRouterRefreshStream(authStream),
      redirect: (BuildContext context, GoRouterState state) async {
        final user = FirebaseAuth.instance.currentUser;
        final isLoggedIn = user != null;
        final isLoggingIn = state.matchedLocation == AppRoutes.login;
        
        // Not logged in and not on login page -> redirect to login
        if (!isLoggedIn && !isLoggingIn) {
          return AppRoutes.login;
        }
        
        // Logged in and on login page -> redirect to home
        if (isLoggedIn && isLoggingIn) {
          return AppRoutes.home;
        }
        
        return null;
      },
      routes: [
        // Login route
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: DeferredWidget(
              libraryLoader: login.loadLibrary,
              childBuilder: () => login.LoginScreen(),
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        ),
        
        // Home/Inbox route
        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: DeferredWidget(
              libraryLoader: inbox.loadLibrary,
              childBuilder: () => inbox.InboxScreen(),
            ),
          ),
        ),
        
        // Inbox route (alias for home)
        GoRoute(
          path: AppRoutes.inbox,
          name: 'inbox',
          redirect: (context, state) => AppRoutes.home,
        ),
        
        // Accounts route
        GoRoute(
          path: AppRoutes.accounts,
          name: 'accounts',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: DeferredWidget(
              libraryLoader: accounts.loadLibrary,
              childBuilder: () => accounts.AccountsScreen(),
            ),
          ),
        ),
        
        // Calendar route
        GoRoute(
          path: AppRoutes.calendar,
          name: 'calendar',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: DeferredWidget(
              libraryLoader: calendar.loadLibrary,
              childBuilder: () => calendar.CalendarScreen(),
            ),
          ),
        ),
        
        // Team route (placeholder)
        GoRoute(
          path: AppRoutes.team,
          name: 'team',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: TeamPlaceholderScreen(),
          ),
        ),
      ],
      errorPageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Page Not Found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.matchedLocation,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Refresh notifier for auth state changes
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<User?> stream) {
    stream.listen((_) => notifyListeners());
  }
}

/// Team placeholder screen
class TeamPlaceholderScreen extends StatelessWidget {
  const TeamPlaceholderScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 24),
            Text(
              'Team Management',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go(AppRoutes.home),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Inbox'),
            ),
          ],
        ),
      ),
    );
  }
}
