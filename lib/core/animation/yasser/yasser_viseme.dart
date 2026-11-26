/// Visible mouth poses mapped to the native `Yasser_Mouth_Rig` shapes (`0..8`).
enum YasserViseme {
  rest(1, 1, 0, 'سكون / ابتسامة'),
  wideOpen(1.12, 1.55, 1, 'فتح واسع (ا / ح / ع)'),
  open(1.04, 1.42, 1, 'فتح واضح (فتحة / مد)'),
  midOpen(1.02, 1.12, 2, 'فتح متوسط (ش / ج / ي)'),
  closed(.97, .12, 3, 'إطباق الشفتين (م / ب)'),
  rounded(.64, 1.18, 4, 'ضم الشفتين (و / ضمة)'),
  labiodental(.92, .62, 5, 'شفوي أسناني (ف)'),
  teeth(1.04, .62, 6, 'أسناني (س / ص / ث / ذ)'),
  consonant(.92, .86, 7, 'نطق ساكن (ل / ر / ن / ك)'),
  calmClosed(.92, .24, 8, 'صمت هادئ (توجيه لطيف)');

  final double width;
  final double height;

  /// Target `mouthShape` ViewModel1 index (`0..8`) in `assets/rive/yasser.riv`.
  final int mouthShapeIndex;

  /// Descriptive Arabic articulatory label for Yasser Lab diagnostics.
  final String arabicLabel;

  const YasserViseme(
    this.width,
    this.height,
    this.mouthShapeIndex,
    this.arabicLabel,
  );

  /// Finds the primary UI viseme matching a raw Rive `mouthShape` (`0..8`) index.
  static YasserViseme fromMouthShapeIndex(int index) {
    return switch (index) {
      1 => YasserViseme.wideOpen,
      2 => YasserViseme.midOpen,
      3 => YasserViseme.closed,
      4 => YasserViseme.rounded,
      5 => YasserViseme.labiodental,
      6 => YasserViseme.teeth,
      7 => YasserViseme.consonant,
      8 => YasserViseme.calmClosed,
      _ => YasserViseme.rest,
    };
  }
}
