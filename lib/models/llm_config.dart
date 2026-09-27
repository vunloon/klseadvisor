class LlmConfig {
  final String baseUrl;
  final String apiKey;
  final String model;

  const LlmConfig({
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
  });

  bool get isConfigured => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  LlmConfig copyWith({String? baseUrl, String? apiKey, String? model}) {
    return LlmConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }
}
