import 'package:flutter/material.dart';

/// A label that always takes exactly one line: when a translation is too
/// long for the space, it shrinks a little instead of wrapping. Side-by-side
/// buttons and fields using it keep the same height in every language.
class OneLineText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const OneLineText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    // The height of one line of this style, so shrinking never changes it.
    final line = TextPainter(
      text: TextSpan(
        text: 'Hg',
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final height = line.height;
    line.dispose();
    final alignment = switch (textAlign) {
      TextAlign.center => Alignment.center,
      TextAlign.end || TextAlign.right => AlignmentDirectional.centerEnd,
      _ => AlignmentDirectional.centerStart,
    };
    return SizedBox(
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: textAlign,
          style: style,
        ),
      ),
    );
  }
}
