import 'package:flutter_test/flutter_test.dart';

import 'package:upsc_questions_app/core/format.dart';
import 'package:upsc_questions_app/core/json.dart';

void main() {
  test('JSON readers never crash on missing or odd values', () {
    final J data = {
      'a': 1,
      'b': '2',
      'c': null,
      'd': {'x': true},
      'e': [1, '2', 'x'],
      'f': [
        {'y': 1},
        'no',
      ],
    };
    expect(data.integer('a'), 1);
    expect(data.integer('b'), 2);
    expect(data.integer('c', 7), 7);
    expect(data.str('missing', '?'), '?');
    expect(data.obj('d').flag('x'), true);
    expect(data.obj('missing'), isEmpty);
    expect(data.ints('e'), [1, 2]);
    expect(data.list('f').single.integer('y'), 1);
  });

  test('formatters', () {
    expect(fmtNum(12.0), '12');
    expect(fmtNum(12.5), '12.5');
    expect(fmtNum(0.6667), '0.67');
    expect(fmtNum(null), '—');
    expect(fmtClock(754), '12:34');
    expect(fmtClock(3700), '1:01:40');
    expect(fmtDuration(45), '45s');
    expect(fmtDuration(754), '12m 34s');
    expect(fmtDateTime(DateTime(2026, 10, 5, 9, 5)), '5 Oct 2026, 09:05');
  });
}
