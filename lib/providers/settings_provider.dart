import 'package:flutter/foundation.dart';

import '../models/llm_config.dart';
import '../services/settings_repository.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repo = SettingsRepository();

  LlmConfig _llm = const LlmConfig();
  bool _autoRefresh = true;
  int _refreshSeconds = 30;
  bool _loaded = false;

  LlmConfig get llm => _llm;
  bool get autoRefresh => _autoRefresh;
  int get refreshSeconds => _refreshSeconds;
  bool get loaded => _loaded;

  Future<void> load() async {
    _llm = await _repo.loadLlmConfig();
    _autoRefresh = await _repo.getAutoRefresh();
    _refreshSeconds = await _repo.getRefreshSeconds();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setBaseUrl(String v) async {
    _llm = _llm.copyWith(baseUrl: v);
    await _repo.saveBaseUrl(v);
    notifyListeners();
  }

  Future<void> setApiKey(String v) async {
    _llm = _llm.copyWith(apiKey: v);
    await _repo.saveApiKey(v);
    notifyListeners();
  }

  Future<void> setModel(String v) async {
    _llm = _llm.copyWith(model: v);
    await _repo.saveModel(v);
    notifyListeners();
  }

  Future<void> setAutoRefresh(bool v) async {
    _autoRefresh = v;
    await _repo.saveAutoRefresh(v);
    notifyListeners();
  }

  Future<void> setRefreshSeconds(int v) async {
    _refreshSeconds = v;
    await _repo.saveRefreshSeconds(v);
    notifyListeners();
  }
}
