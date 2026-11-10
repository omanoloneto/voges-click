import 'package:flutter/material.dart';

/// Colors of the purple band at the top (the same in light and dark themes).
/// The background keeps white text at a 4.5:1 contrast.
abstract final class RibbonColors {
  static const background = Color(0xFF6E47C6);
  static const panel = Color(0xFF6540BA);
  static const panelBorder = Color(0xFF9C7CEB);
  static const field = Color(0xFF5A38A8);
  static const selected = Color(0xFF8D6BE3);
  static const hover = Color(0x26FFFFFF);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFE6DCFC);
  static const divider = Color(0x40FFFFFF);
  static const menu = Color(0xFF6440B8);
}

abstract final class RibbonText {
  static const label = TextStyle(color: RibbonColors.muted, fontSize: 11);
  static const control = TextStyle(color: RibbonColors.text, fontSize: 13);
  static const activeTab = TextStyle(
    color: RibbonColors.text,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
  );
}

/// Theme of the menus opened from the ribbon.
MenuStyle ribbonMenuStyle() => const MenuStyle(
  backgroundColor: WidgetStatePropertyAll(RibbonColors.menu),
  surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
  ),
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 6)),
  maximumSize: WidgetStatePropertyAll(Size(340, 460)),
);

ButtonStyle ribbonMenuItemStyle() => ButtonStyle(
  foregroundColor: const WidgetStatePropertyAll(RibbonColors.text),
  iconColor: const WidgetStatePropertyAll(RibbonColors.text),
  overlayColor: const WidgetStatePropertyAll(RibbonColors.hover),
  textStyle: const WidgetStatePropertyAll(RibbonText.control),
  padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
  minimumSize: const WidgetStatePropertyAll(Size(0, 38)),
  backgroundColor: WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.disabled) ? null : Colors.transparent,
  ),
);
