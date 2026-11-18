import 'package:flutter/material.dart';

/// Stable accent color per Android package / app id.
Color appAccent(String packageName) {
  final hue = packageName.hashCode.abs() % 360;
  return HSLColor.fromAHSL(1, hue.toDouble(), 0.52, 0.48).toColor();
}