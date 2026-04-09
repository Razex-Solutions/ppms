import 'package:flutter/material.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.labelKey,
    required this.icon,
    required this.location,
  });

  final String labelKey;
  final IconData icon;
  final String location;
}
