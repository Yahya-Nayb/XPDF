import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xpdf/screens/chat_screen.dart';
import 'package:xpdf/services/ai_rate_limit_service.dart';
import 'package:xpdf/services/gemini_service.dart';
import 'package:xpdf/services/pdf_text_extraction_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('PDF text extraction reads every page', () async {
    final directory = await Directory.systemTemp.createTemp('xpdf-ai-test-');
    addTearDown(() => directory.delete(recursive: true));

    final document = PdfDocument();
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    document.pages.add().graphics.drawString(
      'First page text',
      font,
      bounds: const Rect.fromLTWH(20, 20, 300, 40),
    );
    document.pages.add().graphics.drawString(
      'Second page text',
      font,
      bounds: const Rect.fromLTWH(20, 20, 300, 40),
    );
    final bytes = document.saveSync();
    document.dispose();

    final file = File('${directory.path}/two-pages.pdf');
    await file.writeAsBytes(bytes);

    final extracted = await PdfTextExtractionService.extractText(file.path);
    expect(extracted, contains('First page text'));
    expect(extracted, contains('Second page text'));
  });

  test('daily AI limit allows 15 questions and rejects the 16th', () async {
    SharedPreferences.setMockInitialValues({});
    final limiter = AiRateLimitService(now: () => DateTime(2026, 9, 13, 12));

    for (var index = 0; index < AiRateLimitService.dailyLimit; index++) {
      final status = await limiter.tryConsumeQuestion();
      expect(status.allowed, isTrue);
      expect(status.remaining, AiRateLimitService.dailyLimit - index - 1);
    }

    final blocked = await limiter.tryConsumeQuestion();
    expect(blocked.allowed, isFalse);
    expect(blocked.remaining, 0);
  });

  test('long PDF preparation retains question-relevant excerpts', () {
    final chunks = List<String>.generate(40, (index) {
      final marker = index == 20
          ? 'The zephyrproject deadline is Friday. '
          : 'General document content for section $index. ';
      return marker.padRight(4000, 'x');
    });

    final prepared = GeminiService.preparePdfContent(
      chunks.join(),
      'When is the zephyrproject deadline?',
    );

    expect(prepared.length, lessThanOrEqualTo(GeminiService.maxPdfCharacters));
    expect(prepared, contains('zephyrproject deadline is Friday'));
    expect(prepared, startsWith('[Long PDF:'));
  });

  testWidgets('chat shows user, typing, and Gemini response states', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final response = Completer<String>();

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          pdfContent: 'The project deadline is Friday.',
          documentName: 'plan.pdf',
          geminiService: _FakeGeminiService(response.future),
          rateLimitService: AiRateLimitService(
            now: () => DateTime(2026, 9, 13, 12),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('ai-chat-input')),
      'When is the deadline?',
    );
    await tester.tap(find.byKey(const Key('ai-chat-send')));
    await tester.pump();

    expect(find.text('When is the deadline?'), findsOneWidget);
    expect(find.text('Gemini is reading…'), findsOneWidget);

    response.complete('The deadline is Friday.');
    await tester.pumpAndSettle();

    expect(find.text('Gemini is reading…'), findsNothing);
    expect(find.text('The deadline is Friday.'), findsOneWidget);
    expect(find.text('14/15 left'), findsOneWidget);
  });
}

class _FakeGeminiService extends GeminiService {
  final Future<String> response;

  _FakeGeminiService(this.response) : super(apiKey: 'test-key');

  @override
  Future<String> sendMessage(String pdfContent, String userQuestion) =>
      response;
}
