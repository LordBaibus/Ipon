import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/expense.dart';

class OcrService {
  OcrService._();
  static Future<ReceiptScanResult> scanReceipt(String imagePath) async {
    if (!File(imagePath).existsSync()) {
      return const ReceiptScanResult();
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(inputImage);
      final lines = <String>[];
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          final text = line.text.trim();
          if (text.isNotEmpty) lines.add(text);
        }
      }

      return parseReceiptLines(lines, rawText: recognized.text);
    } catch (_) {
      return const ReceiptScanResult();
    } finally {
      await recognizer.close();
    }
  }
  static const _totalLabels = <String>[
    'GRAND TOTAL',
    'AMOUNT DUE',
    'TOTAL DUE',
    'TOTAL AMOUNT',
    'NET TOTAL',
    'TOTAL',
  ];
  static const _excludedLabels = <String>[
    'SUBTOTAL',
    'SUB-TOTAL',
    'SUB TOTAL',
    'VATABLE',
    'VAT AMOUNT',
    'VAT-EXEMPT',
    'VAT EXEMPT',
    'ZERO RATED',
    'CHANGE',
    'CASH',
    'TENDERED',
    'TENDER',
    'PAYMENT',
    'DISCOUNT',
    'QTY',
    'ITEMS',
  ];
  static const _merchantNoise = <String>[
    'OFFICIAL RECEIPT',
    'SALES INVOICE',
    'RECEIPT',
    'INVOICE',
    'TIN',
    'VAT REG',
    'NON-VAT',
    'BIR',
    'ACCR',
    'SERIAL',
    'PERMIT',
    'MIN ',
    'THANK YOU',
    'CUSTOMER COPY',
    'WELCOME',
  ];
  static final RegExp _moneyPattern = RegExp(
    r'(?:₱|PHP|P)?\s*(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _isoDate = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})');
  static final RegExp _slashDate = RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})');
  static ReceiptScanResult parseReceiptLines(
      List<String> lines, {
        String rawText = '',
      }) {
    if (lines.isEmpty) {
      return ReceiptScanResult(rawText: rawText);
    }

    final amountResult = _findTotal(lines);

    return ReceiptScanResult(
      amount: amountResult.value,
      amountFromTotalLine: amountResult.fromLabelledLine,
      merchant: _findMerchant(lines),
      date: _findDate(lines),
      rawText: rawText.isEmpty ? lines.join('\n') : rawText,
    );
  }

  static _AmountMatch _findTotal(List<String> lines) {
    double? best;
    var bestScore = -1;

    for (var i = 0; i < lines.length; i++) {
      final upper = lines[i].toUpperCase();

      if (_containsAny(upper, _excludedLabels)) continue;

      final score = _labelScore(upper);
      if (score < 0) continue;
      var value = _lastMoneyIn(lines[i]);
      if (value == null && i + 1 < lines.length) {
        final nextUpper = lines[i + 1].toUpperCase();
        if (!_containsAny(nextUpper, _excludedLabels) &&
            _labelScore(nextUpper) < 0) {
          value = _lastMoneyIn(lines[i + 1]);
        }
      }

      if (value == null) continue;
      if (score >= bestScore) {
        bestScore = score;
        best = value;
      }
    }

    if (best != null) {
      return _AmountMatch(best, true);
    }
    double? largest;
    for (final line in lines) {
      if (_containsAny(line.toUpperCase(), _excludedLabels)) continue;
      for (final match in _moneyPattern.allMatches(line)) {
        final value = _parseMoney(match.group(1));
        if (value == null) continue;
        if (largest == null || value > largest) largest = value;
      }
    }

    return _AmountMatch(largest, false);
  }
  static int _labelScore(String upperLine) {
    for (var i = 0; i < _totalLabels.length; i++) {
      if (upperLine.contains(_totalLabels[i])) {
        return _totalLabels.length - i;
      }
    }
    return -1;
  }

  static String? _findMerchant(List<String> lines) {
    final limit = lines.length < 6 ? lines.length : 6;

    for (var i = 0; i < limit; i++) {
      final line = lines[i].trim();
      final upper = line.toUpperCase();

      if (line.length < 3 || line.length > 60) continue;
      if (_containsAny(upper, _merchantNoise)) continue;
      if (_containsAny(upper, _excludedLabels)) continue;
      final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
      final digits = RegExp(r'[0-9]').allMatches(line).length;
      if (letters < 3) continue;
      if (digits > letters) continue;

      return _tidyMerchant(line);
    }

    return null;
  }
  static String _tidyMerchant(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned != cleaned.toUpperCase()) return cleaned;

    return cleaned
        .split(' ')
        .map((word) {
      if (word.isEmpty) return word;
      if (word.length <= 3 && word == word.toUpperCase()) {
        return word;
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    })
        .join(' ');
  }

  static String? _findDate(List<String> lines) {
    for (final line in lines) {
      final iso = _isoDate.firstMatch(line);
      if (iso != null) {
        final formatted = _formatDate(
          int.tryParse(iso.group(1) ?? ''),
          int.tryParse(iso.group(2) ?? ''),
          int.tryParse(iso.group(3) ?? ''),
        );
        if (formatted != null) return formatted;
      }

      final slash = _slashDate.firstMatch(line);
      if (slash != null) {
        var year = int.tryParse(slash.group(3) ?? '');
        final first = int.tryParse(slash.group(1) ?? '');
        final second = int.tryParse(slash.group(2) ?? '');
        if (year == null || first == null || second == null) continue;

        if (year < 100) year += 2000;
        final month = first > 12 ? second : first;
        final day = first > 12 ? first : second;

        final formatted = _formatDate(year, month, day);
        if (formatted != null) return formatted;
      }
    }

    return null;
  }

  static String? _formatDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    if (year < 2000 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;

    final mm = month.toString().padLeft(2, '0');
    final dd = day.toString().padLeft(2, '0');
    return '$year-$mm-$dd';
  }
  static double? _lastMoneyIn(String line) {
    double? last;
    for (final match in _moneyPattern.allMatches(line)) {
      final value = _parseMoney(match.group(1));
      if (value != null) last = value;
    }
    return last;
  }

  static double? _parseMoney(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(',', '').trim();
    final value = double.tryParse(cleaned);
    if (value == null || value <= 0) return null;
    return value;
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}

class _AmountMatch {
  final double? value;
  final bool fromLabelledLine;

  const _AmountMatch(this.value, this.fromLabelledLine);
}