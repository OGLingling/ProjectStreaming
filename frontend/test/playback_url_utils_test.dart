import 'package:flutter_test/flutter_test.dart';
import 'package:MovieWind/utils/playback_url_utils.dart';

void main() {
  group('playback URL classification', () {
    test('stores HLS URLs without promoting them during embedded playback', () {
      const hlsUrl = 'https://cdn.test/master.m3u8';

      expect(isHlsPlaybackUrl(hlsUrl), isTrue);
      expect(shouldPromoteNativePlaybackUrl(hlsUrl), isFalse);
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
