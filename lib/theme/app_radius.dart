import 'package:flutter/material.dart';

class AppRadius {
  AppRadius._();

  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 18;
  static const double full = 9999;

  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rXl => BorderRadius.circular(xl);
  static BorderRadius get rFull => BorderRadius.circular(full);
}
