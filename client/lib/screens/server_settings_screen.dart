import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api.dart';
import '../config.dart';
import '../services/server_config.dart';

class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key, required this.currentBaseUrl});

  final String currentBaseUrl;

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  late final TextEditingController _controller;
  String? _message;
  bool _error = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentBaseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _say(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _error = error;
    });
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      final reachable = await ServerConfig.isReachable(_controller.text);
      _say(
        reachable ? 'ClassMate API responded on this address.' : 'No API responded here. Check the PC, port 3000 and Windows Firewall.',
        error: !reachable,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _autoDetect() async {
    setState(() => _busy = true);
    try {
      final found = await ServerConfig.discover();
      if (found == null) {
        _say('No API found on this Wi-Fi. Start the server and allow TCP 3000.', error: true);
        return;
      }
      setState(() => _controller.text = found);
      _say('Found $found. Save to use it.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    try {
      final baseUrl = ServerConfig.normalizeBaseUrl(_controller.text);
      setState(() => _busy = true);
      final reachable = await ServerConfig.isReachable(baseUrl);
      if (!reachable) {
        _say('No API responded here. Check the PC, port 3000 and Windows Firewall.', error: true);
        return;
      }
      await ServerConfig.saveOverride(baseUrl);
      if (!mounted) return;
      context.read<Api>().baseUrl = baseUrl;
      Navigator.of(context).pop(true);
    } on FormatException catch (e) {
      _say(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    await ServerConfig.clearOverride();
    if (!mounted) return;
    final baseUrl = ServerConfig.normalizeBaseUrl(AppConfig.apiBaseUrl);
    _controller.text = baseUrl;
    context.read<Api>().baseUrl = baseUrl;
    _say('Reset to the build default. Auto-detect will run on next launch.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server settings')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Local network only',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'The phone and the PC must be on the same Wi-Fi. The app '
                'auto-detects the PC on launch; you can set it manually here '
                'if the network changes or auto-detect is blocked.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'API base URL',
                  hintText: 'http://192.168.5.234:3000/api',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_message != null)
                Text(
                  _message!,
                  style: TextStyle(
                    color: _error ? Colors.redAccent.shade100 : Colors.greenAccent.shade200,
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save and use this server'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _autoDetect,
                icon: const Icon(Icons.wifi_find_outlined),
                label: const Text('Auto-detect on this Wi-Fi'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _busy ? null : _test,
                icon: const Icon(Icons.network_check_outlined),
                label: const Text('Test connection'),
              ),
              TextButton(
                onPressed: _busy ? null : _reset,
                child: const Text('Reset to build default'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
