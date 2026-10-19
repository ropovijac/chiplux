import 'package:flutter/material.dart';

/// Chiplux brand colors. Decorative accents should come from this file.
/// Achievement-tier palettes and semantic success/error colors are separate.
const Color chipluxBackground = Color(0xFF040811);
const Color chipluxSurface = Color(0xFF10151E);
const Color chipluxSurfaceLight = Color(0xFF1A202A);

const Color chipluxGold = Color(0xFFFFD21A);
const Color chipluxBrightGold = Color(0xFFFFE535);
const Color chipluxAmber = Color(0xFFFFAA00);

/// Low-contrast gold for headings and other branded text/icon shaders.
const LinearGradient chipluxTextGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [chipluxGold, chipluxBrightGold],
);

/// Slightly richer gradient for buttons and decorative borders.
const LinearGradient chipluxAccentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [chipluxGold, chipluxAmber],
);
