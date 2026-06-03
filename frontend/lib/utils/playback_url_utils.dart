bool isHlsPlaybackUrl(String? url) {
  final lower = String.fromCharCodes((url ?? '').codeUnits).toLowerCase();
  return lower.contains('.m3u8') ||
      lower.contains('/playlist.m3u8') ||
      lower.contains('master.m3u8') ||
      lower.contains('manifest.m3u8') ||
      lower.contains('application/x-mpegurl');
}

bool shouldPromoteNativePlaybackUrl(String? url) {
  return isHlsPlaybackUrl(url);
}
