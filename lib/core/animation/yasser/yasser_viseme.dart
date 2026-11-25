/// Visible mouth poses available on the current Yasser rig.
enum YasserViseme {
  rest(1, 1),
  teeth(1.04, .62),
  open(1.04, 1.42),
  closed(.97, .12),
  rounded(.64, 1.18),
  consonant(.92, .86);

  final double width;
  final double height;
  const YasserViseme(this.width, this.height);
}
