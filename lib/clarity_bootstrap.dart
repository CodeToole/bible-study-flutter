import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:clarity_flutter/clarity_flutter.dart';

Widget buildAppWithClarity(Widget app) {
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    final config = ClarityConfig(
      projectId: "yhqe50cco9",
      logLevel: kDebugMode ? LogLevel.Verbose : LogLevel.None,
    );
    return ClarityWidget(
      app: app,
      clarityConfig: config,
    );
  }
  return app;
}
