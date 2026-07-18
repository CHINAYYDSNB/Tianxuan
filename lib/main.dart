import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/settings_provider.dart';
import 'services/storage_service.dart';
import 'services/logto_service.dart';
import 'services/logto_bridge.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.migrateIfNeeded();
  runApp(const ProviderScope(child: OnePanelApp()));
}

class OnePanelApp extends StatelessWidget {
  const OnePanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Tianxuan',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.light(
            surface: const Color(0xFFEBEDF5), // 页面背景
            onSurface: const Color(0xFF0C1014), // 文字颜色
            onSurfaceVariant: const Color(0xFF686F78), // 按钮文字颜色
            outline: const Color(0xFFAAB4BF), // 按钮边框颜色
            primary: const Color(0xFF0062F5), // 主题色
          ),
          scaffoldBackgroundColor: const Color(0xFFEBEDF5), // 页面背景
          appBarTheme: const AppBarTheme(
            titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF0C1014)),
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFFFFFFFF),
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(17))),
          ),
          splashFactory: NoSplash.splashFactory, // 禁用水波纹
          highlightColor: Colors.transparent, // 禁用高亮
          splashColor: Colors.transparent, // 禁用水波纹
          hoverColor: Colors.transparent, // 禁用悬停效果
          focusColor: Colors.transparent, // 禁用焦点效果
        ),
        home: const InitPage(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomePage(),
        },
    );
  }
}

class InitPage extends ConsumerStatefulWidget {
  const InitPage({super.key});

  @override
  ConsumerState<InitPage> createState() => _InitPageState();
}

class _InitPageState extends ConsumerState<InitPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => _checkConfig());
    // Safety timeout: fallback to home
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  Future<void> _checkConfig() async {
    try {
      // Web: handle Logto OIDC callback params from URL
      if (kIsWeb) {
        await _handleLogtoCallback();
      }

      final settings = ref.read(settingsProvider.notifier);
      await settings.init();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      debugPrint('InitPage._checkConfig error: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  Future<void> _handleLogtoCallback() async {
    final code = LogtoBridge.extractCallbackParams()['code'];
    final state = LogtoBridge.extractCallbackParams()['state'];
    if (code == null || state == null) return;

    final saved = await StorageService.instance.getLogtoPending();
    if (saved == null || state != saved['state']) return;

    await LogtoService.exchangeCode(
      code: code,
      verifier: saved['verifier'] ?? '',
      redirectUri: LogtoBridge.callbackUri,
      state: state,
      expectedState: saved['state'],
    );
    await StorageService.instance.clearLogtoPending();
    LogtoBridge.clearCallbackParams();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
