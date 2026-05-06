enum OverlayMode {
  normal,
  focus,
  compact,
  clickThrough,
}

extension OverlayModeX on OverlayMode {
  String get key => switch (this) {
        OverlayMode.normal => 'normal',
        OverlayMode.focus => 'focus',
        OverlayMode.compact => 'compact',
        OverlayMode.clickThrough => 'click_through',
      };

  static OverlayMode fromKey(String key) {
    return OverlayMode.values.firstWhere(
      (mode) => mode.key == key,
      orElse: () => OverlayMode.normal,
    );
  }
}
