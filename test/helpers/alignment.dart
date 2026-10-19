import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';

/// Rows of equal-width items (buttons, tabs, chips, cards: the `Expanded`
/// children of one `Row`) whose items came out with different heights,
/// usually because one label wrapped onto a second line in this language.
/// Each entry names the row's items by their text.
List<String> misalignedRows(WidgetTester tester, {double tolerance = 1.0}) {
  final found = <String>[];

  String textOf(RenderObject root) {
    final parts = <String>[];
    void walk(RenderObject r) {
      if (r is RenderParagraph) {
        final t = r.text.toPlainText().trim();
        if (t.isNotEmpty) parts.add(t);
      }
      r.visitChildren(walk);
    }

    walk(root);
    return parts.join(' ');
  }

  void visit(RenderObject r) {
    if (r is RenderFlex && r.direction == Axis.horizontal && r.hasSize) {
      final items = <RenderBox>[];
      int? flex;
      var same = true;
      var child = r.firstChild;
      while (child != null) {
        final data = child.parentData! as FlexParentData;
        final f = data.flex ?? 0;
        if (f > 0) {
          flex ??= f;
          if (f != flex) same = false;
          items.add(child);
        }
        child = data.nextSibling;
      }
      if (same && items.length >= 2 && items.every((i) => i.hasSize)) {
        final heights = items.map((i) => i.size.height).toList();
        final spread = heights.reduce(math.max) - heights.reduce(math.min);
        if (spread > tolerance) {
          found.add(
            items
                .map(
                  (i) => '"${textOf(i)}" ${i.size.height.toStringAsFixed(0)}',
                )
                .join(' | '),
          );
        }
      }
    }
    r.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return found;
}

/// Checks that every group in [groups] whose keys are all on screen lines
/// up: the same top and the same height for each item.
void expectAlignedGroups(
  WidgetTester tester,
  List<List<String>> groups, {
  double tolerance = 1.0,
}) {
  for (final group in groups) {
    final finders = [for (final k in group) find.byKey(ValueKey(k))];
    if (finders.any((f) => f.evaluate().length != 1)) continue;
    final rects = [for (final f in finders) tester.getRect(f)];
    final tops = rects.map((r) => r.top);
    final heights = rects.map((r) => r.height);
    final spread = math.max(
      tops.reduce(math.max) - tops.reduce(math.min),
      heights.reduce(math.max) - heights.reduce(math.min),
    );
    expect(
      spread,
      lessThanOrEqualTo(tolerance),
      reason: '${group.join(', ')} are not aligned: $rects',
    );
  }
}
