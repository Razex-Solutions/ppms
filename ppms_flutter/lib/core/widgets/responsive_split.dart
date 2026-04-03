import 'package:flutter/material.dart';

class ResponsiveSplit extends StatelessWidget {
  const ResponsiveSplit({
    super.key,
    required this.primary,
    required this.secondary,
    this.breakpoint = 1100,
    this.spacing = 16,
    this.primaryFlex = 5,
    this.secondaryFlex = 4,
  });

  final Widget primary;
  final Widget secondary;
  final double breakpoint;
  final double spacing;
  final int primaryFlex;
  final int secondaryFlex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              primary,
              SizedBox(height: spacing),
              secondary,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: primaryFlex, child: primary),
            SizedBox(width: spacing),
            Expanded(flex: secondaryFlex, child: secondary),
          ],
        );
      },
    );
  }
}
