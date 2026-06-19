import 'package:flutter/material.dart';
import 'package:libera/common/responsive.dart';

/// Shows [builder] as a bottom sheet on compact (phone) layouts and as a
/// centered, width-constrained dialog on wide (tablet/desktop) layouts.
///
/// Drop-in replacement for `showModalBottomSheet` call sites: the same builder
/// works in both presentations because the dialog caps height and width and
/// lets the content's own scrolling take over.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool useSafeArea = true,
  double maxDialogWidth = 560,
  double maxDialogHeightFactor = 0.85,
  ShapeBorder? sheetShape,
}) {
  final bg = backgroundColor ?? const Color(0xFF1C1C1E);

  if (!context.isWide) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: backgroundColor,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      useSafeArea: useSafeArea,
      shape:
          sheetShape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
      builder: builder,
    );
  }

  final maxHeight = MediaQuery.sizeOf(context).height * maxDialogHeightFactor;
  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    builder: (ctx) => Dialog(
      backgroundColor: bg,
      insetPadding: const EdgeInsets.all(28),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        // Width is capped; height is loose up to the cap so `mainAxisSize: min`
        // sheet bodies stay compact while scrollable ones can grow to the cap.
        constraints: BoxConstraints(maxWidth: maxDialogWidth, maxHeight: maxHeight),
        child: builder(ctx),
      ),
    ),
  );
}
