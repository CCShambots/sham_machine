import 'dart:ui';

import 'package:flutter/material.dart';

class StyleConstants {
  static TextStyle titleStyle = const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 48,
  );

  static TextStyle subtitleStyle = const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 24,
  );

  static TextStyle h3Style =
      const TextStyle(fontWeight: FontWeight.bold, fontSize: 18);

  static TextStyle statStyle =
      const TextStyle(fontWeight: FontWeight.bold, fontSize: 32);

  static BoxDecoration shadedDecoration(BuildContext context) {
    return BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: Theme.of(context).colorScheme.inverseSurface.withOpacity(0.2));
  }

  static BoxDecoration alternateShadedDecoration(BuildContext context) {
    return BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: Theme.of(context).colorScheme.inversePrimary.withOpacity(0.8));
  }

  static BoxDecoration warningShadedDecoration(BuildContext context) {
    return BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: Colors.yellow.withOpacity(0.3));
  }

  static EdgeInsets margin = const EdgeInsets.all(8);
  static EdgeInsets padding = const EdgeInsets.fromLTRB(16, 8, 16, 8);
}
