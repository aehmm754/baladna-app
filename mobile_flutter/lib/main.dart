import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/ads/create_ad_wizard.dart';
import 'features/auth/phone_auth_sheet.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://keumobvevaxafrqzulcj.supabase.co'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_idHH0ndkiXyvcTpgHwjUgw_uVRXNG0'),
  );
  runApp(const BaladnaApp());
}

class BaladnaApp extends StatefulWidget {
  const BaladnaApp({super.key});

  @override
  State<BaladnaApp> createState() => _BaladnaAppState();
}

class _BaladnaAppState extends State<BaladnaApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بلدنا',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SY'),
      supportedLocales: const [Locale('ar', 'SY'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: _MainShell(onToggleTheme: _toggleTheme),
    );
  }
}

class _MainShell extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const _MainShell({required this.onToggleTheme});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onToggleTheme: widget.onToggleTheme),
          const Center(child: Text('المفضلة — سجّل دخولك لعرض إعلاناتك المحفوظة')),
          const Center(child: Text('محادثاتك الفورية')),
          const Center(child: Text('ملفك الشخصي وإعلاناتك')),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('أضف إعلان'),
        onPressed: () async {
          if (!await requireAuth(context)) return;
          if (!context.mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateAdWizard()));
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          if (i > 0 && !await requireAuth(context)) return;
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.favorite_rounded), label: 'المفضلة'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_rounded), label: 'الدردشة'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'حسابي'),
        ],
      ),
    );
  }
}
