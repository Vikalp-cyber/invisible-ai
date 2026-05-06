class WindowDescriptor {
  const WindowDescriptor({
    required this.id,
    this.isPrimary = false,
  });

  final String id;
  final bool isPrimary;
}

class OverlayWindowIds {
  static const String main = 'main';
}
