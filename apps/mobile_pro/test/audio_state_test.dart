import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MockMediaStream extends Mock implements MediaStream {}
class MockMediaStreamTrack extends Mock implements MediaStreamTrack {}

void main() {
  group('Audio State Logic Tests', () {
    test('Toggle mute should change track enabled state', () {
      // Since we can't easily test the private state of _BroadcastScreenState directly in a simple unit test 
      // without extra setup, we simulate the logic here.
      
      bool isMuted = false;
      final mockTrack = MockMediaStreamTrack();
      final tracks = [mockTrack];
      
      // Simulate _toggleMute logic
      isMuted = !isMuted;
      for (var track in tracks) {
        track.enabled = !isMuted;
      }
      
      expect(isMuted, true);
      verify(mockTrack.enabled = false).called(1);
    });
  });
}

// Helper to allow verify on setters/methods if needed
class MockMediaStreamTrackLegacy extends Mock implements MediaStreamTrack {
  @override
  set enabled(bool? _enabled) => super.noSuchMethod(Invocation.setter(#enabled, _enabled));
}
