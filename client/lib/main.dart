import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/api.dart';
import 'api/api_client.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';
import 'state/auth_state.dart';
import 'state/token_store.dart';
import 'theme.dart';

void main() {
  final api = Api(ApiClient());
  runApp(
    ClassMateApp(
      api: api,
      auth: AuthState(api, TokenStore()),
      appState: AppState(api),
    ),
  );
}

class ClassMateApp extends StatelessWidget {
  const ClassMateApp({
    super.key,
    required this.api,
    required this.auth,
    required this.appState,
  });

  final Api api;
  final AuthState auth;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Api>.value(value: api),
        ChangeNotifierProvider<AuthState>.value(value: auth),
        ChangeNotifierProvider<AppState>.value(value: appState),
      ],
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'ClassMate',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: state.themeMode,
          home: const _Root(),
        ),
      ),
    );
  }
}

/// Decides between the login flow and the signed-in shell, and keeps [AppState]
/// in sync with the auth state.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late final AuthState _auth;
  int? _loadedUserId;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthState>();
    _auth.addListener(_onAuthChanged);
    _auth.restore();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final app = context.read<AppState>();
    if (_auth.isAuthenticated) {
      final userId = _auth.user!.id;
      if (_loadedUserId != userId) {
        _loadedUserId = userId;
        app.switchAccount(userId).then((_) {
          if (mounted) app.refreshAll();
        });
      } else if (app.dashboard == null && !app.loading && app.error == null) {
        app.refreshAll();
      }
    } else {
      _loadedUserId = null;
      app.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (!auth.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isAuthenticated ? const HomeShell() : const LoginScreen();
  }
}
