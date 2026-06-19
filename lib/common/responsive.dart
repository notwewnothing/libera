import 'package:flutter/widgets.dart';

/// Width breakpoints for adaptive layout.
///
/// - [compact]  : phones / narrow windows (< 700)   → bottom nav, 1-up details
/// - [medium]   : tablets / split windows (700–1100) → rail, denser grids
/// - [expanded] : desktop / large windows (> 1100)   → rail, 2-column details
enum Breakpoint { compact, medium, expanded }

const double _kMediumMin = 700;
const double _kExpandedMin = 1100;

/// Max width content is allowed to occupy on very wide screens (it gets
/// centered beyond this so rows/text don't stretch awkwardly).
const double kContentMaxWidth = 1280;

Breakpoint breakpointForWidth(double width) {
  if (width >= _kExpandedMin) return Breakpoint.expanded;
  if (width >= _kMediumMin) return Breakpoint.medium;
  return Breakpoint.compact;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  Breakpoint get breakpoint => breakpointForWidth(screenWidth);

  /// Phone-style layout (bottom nav, single column, bottom sheets).
  bool get isCompact => breakpoint == Breakpoint.compact;

  /// Tablet-or-larger (navigation rail, centered dialogs, grids).
  bool get isWide => breakpoint != Breakpoint.compact;

  /// Desktop-scale (two-column detail pages, widest grids).
  bool get isExpanded => breakpoint == Breakpoint.expanded;

  /// Horizontal page padding that grows with available width.
  double get hPad => switch (breakpoint) {
    Breakpoint.compact => 16,
    Breakpoint.medium => 28,
    Breakpoint.expanded => 44,
  };

  /// A pleasant target tile width for poster grids/rows at this breakpoint;
  /// feed into [SliverGridDelegateWithMaxCrossAxisExtent.maxCrossAxisExtent].
  double get posterTileExtent => switch (breakpoint) {
    Breakpoint.compact => 124,
    Breakpoint.medium => 150,
    Breakpoint.expanded => 168,
  };
}

/// Constrains [child] to [kContentMaxWidth] and centers it. No-op visually on
/// narrow screens. Use to wrap page bodies so content doesn't span ultrawide.
class MaxWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  const MaxWidth({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
