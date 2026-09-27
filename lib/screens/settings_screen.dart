import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../providers/watchlist_provider.dart';
import '../services/llm_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  late TextEditingController _tokenCtrl;
  late TextEditingController _modelCtrl;

  bool _obscureToken = true;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _urlCtrl = TextEditingController(text: settings.llm.baseUrl);
    _tokenCtrl = TextEditingController(text: settings.llm.apiKey);
    _modelCtrl = TextEditingController(text: settings.llm.model);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final sp = context.read<SettingsProvider>();
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final ok = await LlmService().testConnection(sp.llm);
      setState(() {
        _testing = false;
        _testOk = ok;
        _testResult = ok
            ? 'Connection successful — LLM replied.'
            : 'Connected but empty response.';
      });
    } catch (e) {
      setState(() {
        _testing = false;
        _testOk = false;
        _testResult = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sp = context.watch<SettingsProvider>();
    final wp = context.read<WatchlistProvider>();
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Settings',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),

          _sectionTitle(context, 'LLM Analysis API'),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(
                  controller: _urlCtrl,
                  label: 'API Base URL',
                  hint: 'https://api.openai.com',
                  helper:
                      'OpenAI-compatible. Examples: https://api.openai.com, https://api.deepseek.com, http://<host>:11434 (Ollama), https://openrouter.ai/api',
                  onChanged: sp.setBaseUrl,
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _tokenCtrl,
                  label: 'API Token / Key',
                  hint: 'sk-… (leave empty if not required)',
                  obscure: _obscureToken,
                  onChanged: sp.setApiKey,
                  suffix: IconButton(
                    icon: Icon(_obscureToken
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscureToken = !_obscureToken),
                  ),
                ),
                const SizedBox(height: 14),
                _field(
                  controller: _modelCtrl,
                  label: 'Model',
                  hint: 'gpt-4o-mini / deepseek-chat / llama3.1',
                  onChanged: sp.setModel,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.tonalIcon(
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check, size: 18),
                      label: Text(_testing ? 'Testing…' : 'Test Connection'),
                      onPressed: _testing ? null : _testConnection,
                    ),
                    const Spacer(),
                    Text(
                      sp.llm.isConfigured ? 'Configured' : 'Not configured',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sp.llm.isConfigured
                            ? const Color(0xFF16A34A)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _testOk ? Icons.check_circle : Icons.error_outline,
                        size: 16,
                        color: _testOk ? const Color(0xFF16A34A) : scheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _testResult!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _testOk
                                ? const Color(0xFF16A34A)
                                : scheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          _sectionTitle(context, 'Data Refresh'),
          _card(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-refresh quotes',
                      style: TextStyle(fontSize: 14)),
                  subtitle: Text(
                      'Watchlist refreshes automatically in the background',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  value: sp.autoRefresh,
                  onChanged: (v) async {
                    await sp.setAutoRefresh(v);
                    wp.restartAutoRefresh();
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Text('Refresh interval',
                          style: TextStyle(fontSize: 14)),
                      const Spacer(),
                      SegmentedButton<int>(
                        style: const ButtonStyle(
                          visualDensity:
                              VisualDensity(horizontal: -3, vertical: -2),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        segments: const [
                          ButtonSegment(value: 15, label: Text('15s', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: 30, label: Text('30s', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: 60, label: Text('1m', style: TextStyle(fontSize: 11))),
                          ButtonSegment(value: 300, label: Text('5m', style: TextStyle(fontSize: 11))),
                        ],
                        selected: {sp.refreshSeconds},
                        onSelectionChanged: (s) async {
                          await sp.setRefreshSeconds(s.first);
                          wp.restartAutoRefresh();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _sectionTitle(context, 'About'),
          _card(
            child: Text(
              'KLSE Advisor — long-term investment research for Bursa Malaysia.\n\n'
              '• Market data: Yahoo Finance (delayed). Tickers use the .KL suffix.\n'
              '• Screening & scoring run on-device from Yahoo fundamentals.\n'
              '• AI research notes are generated by the LLM API you configure above; your API token is stored in Android secure storage.\n\n'
              'Disclaimer: For research and education only — not investment advice. Do your own due diligence before investing.',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  Widget _card({required Widget child}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    String? helper,
    bool obscure = false,
    Widget? suffix,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: !obscure,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            suffixIcon: suffix,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: scheme.primary, width: 1.6),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(helper,
              style:
                  TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, height: 1.35)),
        ],
      ],
    );
  }
}
