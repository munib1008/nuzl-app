import 'package:flutter/material.dart';

/// Premium two-layer elevation — a tight contact shadow plus a soft, wide
/// ink-tinted ambient shadow. Matches the depth used on the landing hero
/// dashboard preview so in-app cards read as "valuable", not flat.
///
/// Reference: box-shadow: 0 1px 3px rgba(0,0,0,.04), 0 10px 30px rgba(23,43,54,.06);
class AppShadows {
  AppShadows._();

  /// Resting card depth.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F172B36), blurRadius: 30, offset: Offset(0, 10)),
  ];

  /// Hover / active card — deeper, for the lift affordance.
  static const List<BoxShadow> cardHover = [
    BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x21172B36), blurRadius: 40, offset: Offset(0, 18)),
  ];
}
