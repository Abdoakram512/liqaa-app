import 'package:equatable/equatable.dart';

class PhonemeToken extends Equatable {
  final String symbol; // e.g., 'k', 'uː', 'r', 'a'
  final String arabicSymbol; // e.g., 'ك', 'و', 'ر', 'ة'
  final int tokenId;
  final double confidence; // 0.0 to 1.0
  final double acousticMargin; // margin over second best
  final int startFrame;
  final int endFrame;
  final int startMs;
  final int endMs;
  final bool isAccurate;

  const PhonemeToken({
    required this.symbol,
    required this.arabicSymbol,
    this.tokenId = 0,
    required this.confidence,
    this.acousticMargin = 0.25,
    this.startFrame = 0,
    this.endFrame = 0,
    this.startMs = 0,
    this.endMs = 0,
    this.isAccurate = true,
  });

  factory PhonemeToken.fromJson(Map<String, dynamic> json) {
    return PhonemeToken(
      symbol: json['symbol'] as String? ?? '',
      arabicSymbol: json['arabic_symbol'] as String? ?? '',
      tokenId: json['token_id'] as int? ?? 0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      acousticMargin: (json['acoustic_margin'] as num?)?.toDouble() ?? 0.2,
      startFrame: json['start_frame'] as int? ?? 0,
      endFrame: json['end_frame'] as int? ?? 0,
      startMs: json['start_ms'] as int? ?? 0,
      endMs: json['end_ms'] as int? ?? 0,
      isAccurate: json['is_accurate'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'arabic_symbol': arabicSymbol,
    'token_id': tokenId,
    'confidence': confidence,
    'acoustic_margin': acousticMargin,
    'start_frame': startFrame,
    'end_frame': endFrame,
    'start_ms': startMs,
    'end_ms': endMs,
    'is_accurate': isAccurate,
  };

  @override
  List<Object?> get props => [
    symbol,
    arabicSymbol,
    tokenId,
    confidence,
    startMs,
    endMs,
    isAccurate,
  ];
}
