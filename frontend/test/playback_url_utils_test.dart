import 'package:flutter_test/flutter_test.dart';
import 'package:MovieWind/utils/playback_url_utils.dart';

void main() {
  group('playback URL classification', () {
    test('promotes only HLS URLs to native playback', () {
      expect(
        shouldPromoteNativePlaybackUrl('https://cdn.test/master.m3u8'),
        isTrue,
      );
      expect(
        shouldPromoteNativePlaybackUrl('https://cdn.test/movie.mp4'),
        isFalse,
      );
      expect(
        shouldPromoteNativePlaybackUrl(
          'https://googlevideo.com/videoplayback?id=abc',
        ),
        isFalse,
      );
    });
  });
}
