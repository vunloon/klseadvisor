import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/klse_universe.dart';
import '../models/llm_config.dart';

class SettingsRepository {
  static const _keyBaseUrl = 'llm_base_url';
  static const _keyModel = 'llm_model';
  static const _keyApiKey = 'llm_api_key';
  static const _keyAutoRefresh = 'auto_refresh';
  static const _keyRefreshSeconds = 'refresh_seconds';
  static const _keyWatchlist = 'watchlist';

  static const _defaultBaseUrl = 'https://api.openai.com';
  static const _defaultModel = 'gpt-4o-mini';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<String> getBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyBaseUrl) ?? _defaultBaseUrl;
  }

  Future<String> getModel() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyModel) ?? _defaultModel;
  }

  Future<String> getApiKey() async {
    return await _secure.read(key: _keyApiKey) ?? '';
  }

  Future<void> saveBaseUrl(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyBaseUrl, v.trim());
  }

  Future<void> saveModel(String v) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyModel, v.trim());
  }

  Future<void> saveApiKey(String v) async {
    final t = v.trim();
    if (t.isEmpty) {
      await _secure.delete(key: _keyApiKey);
    } else {
      await _secure.write(key: _keyApiKey, value: t);
    }
  }

  Future<bool> getAutoRefresh() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyAutoRefresh) ?? true;
  }

  Future<void> saveAutoRefresh(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keyAutoRefresh, v);
  }

  Future<int> getRefreshSeconds() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyRefreshSeconds) ?? 30;
  }

  Future<void> saveRefreshSeconds(int v) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyRefreshSeconds, v);
  }

  Future<LlmConfig> loadLlmConfig() async {
    return LlmConfig(
      baseUrl: await getBaseUrl(),
      apiKey: await getApiKey(),
      model: await getModel(),
    );
  }

  Future<List<String>> loadWatchlist() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_keyWatchlist);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<String>();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return klseWatchlistDefaults.keys.toList();
  }

  Future<void> saveWatchlist(List<String> symbols) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyWatchlist, jsonEncode(symbols));
  }
}
