import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/widgets/wave_clipper.dart';

void main() {
  test('login wave is horizontal, continuous and bounded', () {
    const clipper = LoginWaveClipper();
    final path = clipper.getClip(const Size(400, 240));
    final bounds = path.getBounds();

    expect(bounds.left, 0);
    expect(bounds.top, 0);
    expect(bounds.right, 400);
    expect(bounds.bottom, greaterThan(210));
    expect(bounds.bottom, lessThan(240));
    expect(clipper.shouldReclip(const LoginWaveClipper()), isFalse);
  });
}
