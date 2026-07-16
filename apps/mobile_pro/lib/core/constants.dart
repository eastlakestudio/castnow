import 'package:flutter/material.dart';

// --- Theme Colors ---
const Color kBackgroundColor = Color(0xFF030712);
const Color kSurfaceColor = Color(0xFF0F172A);
const Color kPrimaryColor = Color(0xFF06B6D4);
const Color kTextPrimary = Color(0xFFF8FAFC);
const Color kTextSecondary = Color(0xFF94A3B8);

// --- Typography ---
const TextStyle kTitleStyle = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.w900,
  color: kTextPrimary,
);

const TextStyle kSubtitleStyle = TextStyle(
  fontSize: 16,
  color: kTextSecondary,
);

enum CastNowLayoutMode { pip, sideBySide }
