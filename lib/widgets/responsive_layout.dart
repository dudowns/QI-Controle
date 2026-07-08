// lib/widgets/responsive_layout.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/layout_provider.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget desktop;
  final Widget? tablet;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.desktop,
    this.tablet,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LayoutProvider>(context);
    final width = MediaQuery.of(context).size.width;

    // ✅ CORRIGIDO: Usa 'updateScreenSize'
    provider.updateScreenSize(width);

    if (provider.isForced) {
      return provider.isMobile ? mobile : desktop;
    }

    if (width < 600) {
      return mobile;
    } else if (width < 1200) {
      return tablet ?? mobile;
    } else {
      return desktop;
    }
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isMobile, bool isDesktop)
      builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LayoutProvider>(context);
    final width = MediaQuery.of(context).size.width;

    provider.updateScreenSize(width);

    bool isMobile;
    if (provider.isForced) {
      isMobile = provider.isMobile;
    } else {
      isMobile = width < 900;
    }

    return builder(context, isMobile, !isMobile);
  }
}
