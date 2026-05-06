class AudioInputDevice {
  const AudioInputDevice({
    required this.id,
    required this.label,
    required this.isVirtualCable,
  });

  final String id;
  final String label;
  final bool isVirtualCable;
}
