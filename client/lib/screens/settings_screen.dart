import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../state/app_state.dart';
import '../state/settings_state.dart';
import '../state/theme_state.dart';
import '../theme.dart';
import '../widgets/v2_kit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: context.read<SettingsState>().serverUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = context.read<SettingsState>();
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await settings.save(_url.text);
      _url.text = settings.serverUrl;
      await app.refreshAll();
      if (mounted) _toast(app.error ?? 'Server address saved');
    } on FormatException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    final api = context.read<Api>();
    setState(() => _busy = true);
    try {
      final user = await api.me();
      if (mounted) _toast('Connected as ${user.email}');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('Connection failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final settings = context.read<SettingsState>();
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await settings.resetServerUrl();
      _url.text = settings.serverUrl;
      await app.refreshAll();
      if (mounted) _toast('Using the build-time server address');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final api = context.read<Api>();
    final colors = context.colors;
    final theme = context.watch<ThemeState>();

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          v2Centered(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeading(
                        title: 'Server connection',
                        subtitle: 'Point the app at the ClassMate API running on your laptop.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Use the laptop\'s LAN address, for example http://192.168.1.24:3000/api. '
                        'The phone and laptop must be on the same Wi-Fi network.',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _url,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'API base URL',
                          hintText: 'http://192.168.1.24:3000/api',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: colors.bgSecondary.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Effective endpoint',
                              style: TextStyle(
                                color: colors.textDim,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              api.baseUrl,
                              style: TextStyle(
                                color: colors.textMain,
                                fontSize: 11.5,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              settings.isCustom
                                  ? 'Source: saved override'
                                  : 'Source: build default',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: PillButton(
                              label: _busy ? 'Saving…' : 'Save',
                              icon: Icons.save_outlined,
                              tone: colors.primary,
                              expand: true,
                              onPressed: _busy ? null : _save,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PillButton(
                              label: 'Test',
                              icon: Icons.wifi_tethering,
                              expand: true,
                              onPressed: _busy ? null : _test,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _busy ? null : _reset,
                        child: const Text('Reset to build default'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          theme.isDark
                              ? Icons.dark_mode_outlined
                              : Icons.light_mode_outlined,
                          color: colors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appearance',
                              style: TextStyle(
                                color: colors.textMain,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              theme.isDark
                                  ? 'Field journal · dark'
                                  : 'Field journal · light',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PillButton(
                        label: theme.isDark ? 'Light' : 'Dark',
                        icon: theme.isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        dense: true,
                        onPressed: theme.toggle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        size: 18,
                        color: colors.amber,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'On the laptop, run the API with “npm start” in server/ and make sure '
                          'port 3000 is reachable on the same Wi-Fi network.',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
