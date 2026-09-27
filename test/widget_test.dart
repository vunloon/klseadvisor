import 'package:flutter_test/flutter_test.dart';
import 'package:klse_advisor/models/stock_detail.dart';
import 'package:klse_advisor/models/stock_quote.dart';
import 'package:klse_advisor/services/llm_service.dart';

void main() {
  test('StockQuote parses Yahoo quote JSON', () {
    final q = StockQuote.fromYahooJson({
      'symbol': '1155.KL',
      'shortName': 'MALAYAN BANKING BHD',
      'longName': 'Malayan Banking Berhad',
      'regularMarketPrice': 10.36,
      'regularMarketChange': 0.10,
      'regularMarketChangePercent': 0.975,
      'currency': 'MYR',
      'marketState': 'REGULAR',
    });
    expect(q.symbol, '1155.KL');
    expect(q.price, 10.36);
    expect(q.isUp, isTrue);
    expect(q.displayName, 'Malayan Banking Berhad');
  });

  test('StockDetail score rewards quality and value', () {
    const d = StockDetail(
      symbol: '1155.KL',
      dividendYield: 6.0,
      roe: 13.0,
      debtToEquity: 0.4,
      trailingPE: 10.0,
      earningsGrowth: 8.0,
      profitMargins: 20.0,
      priceToBook: 1.2,
    );
    expect(d.score, greaterThan(80));
    expect(d.strengths(), contains('High yield'));
  });

  test('StockDetail flags weak companies', () {
    const d = StockDetail(
      symbol: 'X.KL',
      trailingPE: -5.0,
      debtToEquity: 2.5,
      earningsGrowth: -10.0,
    );
    expect(d.warnings(), contains('Loss-making (negative PE)'));
    expect(d.warnings(), contains('High leverage'));
    expect(d.score, lessThan(10));
  });

  test('LlmService resolves common base URL styles', () {
    final s = LlmService();
    expect(
      s.resolveEndpoint('https://api.openai.com').toString(),
      'https://api.openai.com/v1/chat/completions',
    );
    expect(
      s.resolveEndpoint('https://api.deepseek.com/').toString(),
      'https://api.deepseek.com/v1/chat/completions',
    );
    expect(
      s.resolveEndpoint('http://10.0.2.2:11434/v1').toString(),
      'http://10.0.2.2:11434/v1/chat/completions',
    );
    expect(
      s.resolveEndpoint('https://x.ai/v1/chat/completions').toString(),
      'https://x.ai/v1/chat/completions',
    );
  });
}
