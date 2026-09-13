import 'package:flutter/material.dart';

/// Web fallback for Clarity: bypasses native Clarity SDK so web builds
/// and tests compile and run seamlessly without dart2js 64-bit int issues.
Widget buildAppWithClarity(Widget app) {
  return app;
}
