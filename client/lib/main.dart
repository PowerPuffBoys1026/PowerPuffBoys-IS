import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/api.dart';
import 'api/api_client.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'state/app_state.dart';
import 'state/auth_state.dart';
import 'state/token_store.dart';
import 'state/notes_state.dart';
import 'theme.dart';
import 'widgets/animated_glass_background.dart';

void main() {
  final api = Api(ApiClient());
  runApp(ClassMateApp(
    api: api,
    auth: AuthState(api, TokenStore()),
    appState: AppState(api),
    notes: NotesState(api),
  ));
}

class ClassMateApp extends StatelessWidget {
  const ClassMateApp({
    super.key,
    required this.api,
    required this.auth,
    required this.appState,
    required this.notes,
  });

  final Api api;
  final AuthState auth;
  final AppState appState;
  final NotesState notes;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Api>.value(value: api),
        ChangeNotifierProvider<AuthState>.value(value: auth),
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<NotesState>.value(value: notes),
      ],
      child: MaterialApp(
        title: 'ClassMate',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        themeMode: ThemeMode.dark,
        home: const _Root(),
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
    final notes = context.read<NotesState>();
    if (_auth.isAuthenticated) {
      if (app.dashboard == null && !app.loading && app.error == null) {
        app.refreshAll();
      }
      notes.load();
    } else {
      app.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    if (!auth.ready) {
      return const AnimatedGlassBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return AnimatedGlassBackground(
      child: auth.isAuthenticated ? const HomeShell() : const LoginScreen(),
    );
  }
}
