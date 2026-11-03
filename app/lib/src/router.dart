import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:ashna/src/screens/auth_screen.dart";
import "package:ashna/src/screens/deck_screen.dart";
import "package:ashna/src/screens/matches_screen.dart";
import "package:ashna/src/screens/onboarding_screen.dart";
import "package:ashna/src/screens/profile_screen.dart";
import "package:ashna/src/screens/thread_screen.dart";
import "package:ashna/src/session.dart";
import "package:ashna/src/theme.dart";

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.read(sessionProvider);
  final router = GoRouter(
    initialLocation: "/boot",
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      switch (session.status) {
        case SessionStatus.loading:
          return loc == "/boot" ? null : "/boot";
        case SessionStatus.signedOut:
          return loc.startsWith("/auth") ? null : "/auth/phone";
        case SessionStatus.onboarding:
          return loc == "/onboarding" ? null : "/onboarding";
        case SessionStatus.ready:
          if (loc.startsWith("/auth") || loc == "/boot" || loc == "/onboarding") return "/deck";
          return null;
      }
    },
    routes: [
      GoRoute(path: "/boot", builder: (context, state) => const BootScreen()),
      GoRoute(path: "/auth/phone", builder: (context, state) => const PhoneScreen()),
      GoRoute(path: "/auth/otp", builder: (context, state) => const OtpScreen()),
      GoRoute(path: "/onboarding", builder: (context, state) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: "/deck", builder: (context, state) => const DeckScreen()),
          GoRoute(path: "/matches", builder: (context, state) => const MatchesScreen()),
          GoRoute(path: "/me", builder: (context, state) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: "/thread/:id",
        builder: (context, state) => ThreadScreen(
          matchId: state.pathParameters["id"]!,
          name: state.uri.queryParameters["name"] ?? "گفتگو",
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = location.startsWith("/matches") ? 1 : location.startsWith("/me") ? 2 : 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (next) => context.go(["/deck", "/matches", "/me"][next]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style), label: "کشف"),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: "گفتگو"),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: "من"),
        ],
      ),
    );
  }
}

class AshnaApp extends ConsumerWidget {
  const AshnaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: "آشنا",
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale("fa"),
      supportedLocales: const [Locale("fa"), Locale("en")],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink());
      },
    );
  }
}
