import 'package:flutter_test/flutter_test.dart';
import 'package:castnow_pro/core/constants.dart';

void main() {
  group('CastNowLayoutMode Tests', () {
    test('Enum values should be correct', () {
      expect(CastNowLayoutMode.values.length, 2);
      expect(CastNowLayoutMode.pip.index, 0);
      expect(CastNowLayoutMode.sideBySide.index, 1);
    });

    test('Layout mode switching logic simulation', () {
      CastNowLayoutMode currentMode = CastNowLayoutMode.pip;
      
      // Simulate toggle
      currentMode = currentMode == CastNowLayoutMode.pip 
          ? CastNowLayoutMode.sideBySide 
          : CastNowLayoutMode.pip;
      expect(currentMode, CastNowLayoutMode.sideBySide);

      // Simulate toggle back
      currentMode = currentMode == CastNowLayoutMode.pip 
          ? CastNowLayoutMode.sideBySide 
          : CastNowLayoutMode.pip;
      expect(currentMode, CastNowLayoutMode.pip);
    });

    test('Swap logic simulation', () {
      bool isSwapped = false;
      
      // Toggle swap
      isSwapped = !isSwapped;
      expect(isSwapped, true);

      // Toggle back
      isSwapped = !isSwapped;
      expect(isSwapped, false);
    });
  });
}
