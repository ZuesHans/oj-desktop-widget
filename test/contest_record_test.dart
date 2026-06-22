import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  test('ContestRecord JSON roundtrip preserves optional fields', () {
    final contest = _contest();

    final stored = contest.toStorageJson();
    final parsed = ContestRecord.fromJson(stored);

    expect(stored['title'], 'Summer Training Day 1');
    expect(parsed.id, 'contest-a');
    expect(parsed.rank, 3);
    expect(parsed.totalParticipants, 42);
    expect(parsed.solvedCount, 5);
    expect(parsed.penalty, 712);
    expect(parsed.note, 'Upsolved two problems after contest.');
  });

  test('invalid contest data is rejected', () {
    expect(
      ContestRecord.tryFromJson({
        ..._contest().toJson(),
        'rank': 0,
      }),
      isNull,
    );
    expect(
      ContestRecord.tryFromJson({
        ..._contest().toJson(),
        'totalParticipants': 2,
      }),
      isNull,
    );
    expect(
      ContestRecord.tryFromJson({
        ..._contest().toJson(),
        'date': '2026-02-31',
      }),
      isNull,
    );
  });

  test('LocalStore skips damaged contest entries', () async {
    final directory = await Directory.systemTemp.createTemp('contest_store_');
    try {
      final file = File(
        '${directory.path}${Platform.pathSeparator}contests_v1.json',
      );
      await file.writeAsString(jsonEncode([
        _contest().toStorageJson(),
        {'id': 'broken'},
        'not-an-object',
      ]));

      final store = LocalStore(supportDirectory: directory);
      final contests = await store.loadContests();

      expect(contests, hasLength(1));
      expect(contests.single.title, 'Summer Training Day 1');
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('ContestRecordService CRUD, sorting, range filter, and chart points',
      () {
    const service = ContestRecordService();
    final first = _contest(
      id: 'a',
      date: '2026-07-02',
      rank: 9,
      updatedAt: DateTime.parse('2026-07-02T12:00:00'),
    );
    final second = _contest(
      id: 'b',
      date: '2026-07-01',
      rank: 4,
      updatedAt: DateTime.parse('2026-07-01T12:00:00'),
    );
    final third = _contest(
      id: 'c',
      date: '2026-07-03',
      rank: 2,
      updatedAt: DateTime.parse('2026-07-03T12:00:00'),
    );

    var contests = service.upsert(const [], first);
    contests = service.upsert(contests, second);
    contests = service.upsert(contests, third);

    expect(contests.map((item) => item.id), ['c', 'a', 'b']);

    final editedSecond = second.copyWith(
      rank: 1,
      updatedAt: DateTime.parse('2026-07-04T12:00:00'),
    );
    contests = service.upsert(contests, editedSecond);
    expect(contests.map((item) => item.id), ['c', 'a', 'b']);
    expect(contests.last.rank, 1);

    final filtered = service.filterByDateRange(
      contests,
      startDate: '2026-07-02',
      endDate: '2026-07-03',
    );
    expect(filtered.map((item) => item.id), ['c', 'a']);

    final points = service.buildRankPoints(contests);
    expect(points.map((point) => point.record.id), ['b', 'a', 'c']);
    expect(points.map((point) => point.rank), [1, 9, 2]);

    contests = service.remove(contests, 'a');
    expect(contests.map((item) => item.id), ['c', 'b']);
  });
}

ContestRecord _contest({
  String id = 'contest-a',
  String title = 'Summer Training Day 1',
  String date = '2026-07-01',
  int rank = 3,
  int? totalParticipants = 42,
  int? solvedCount = 5,
  int? penalty = 712,
  DateTime? updatedAt,
}) {
  final now = DateTime.parse('2026-07-01T12:00:00');
  return ContestRecord(
    id: id,
    title: title,
    date: date,
    rank: rank,
    totalParticipants: totalParticipants,
    solvedCount: solvedCount,
    penalty: penalty,
    note: 'Upsolved two problems after contest.',
    createdAt: now,
    updatedAt: updatedAt ?? now,
  );
}
