import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../api/api_client.dart';
import '../state/app_state.dart';
import '../state/settings_state.dart';
import '../widgets/animated_glass_background.dart';

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
      if (mounted) {
        final error = app.error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Server address saved')),
        );
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    final api = context.read<Api>();
    setState(() => _busy = true);
    try {
      final user = await api.me();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected as ${user.email}')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection failed: $e')));
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Using the build-time server address')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final api = context.read<Api>();

    return AnimatedGlassBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Server connection', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Text(
                      'The ClassMate API must be reachable from this device. '
                      'Use the laptop\'s LAN address, for example '
                      'http://192.168.1.24:3000/api.',
                      style: Theme.of(context).textTheme.bodySmall,
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
                    Text(
                      'Effective: ${api.baseUrl}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      settings.isCustom ? 'Source: saved override' : 'Source: build default',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : _save,
                            child: const Text('Save'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _busy ? null : _test,
                            child: const Text('Test'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : _reset,
                      child: const Text('Reset to build default'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.tips_and_updates_outlined),
                title: const Text('Tip'),
                subtitle: Text(
                  'On the laptop, run the API with "npm start" in server/ and make sure '
                  'port 3000 is reachable on the same Wi-Fi network.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
