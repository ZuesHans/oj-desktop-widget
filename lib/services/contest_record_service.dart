import '../models/contest_record.dart';

class ContestRecordService {
  const ContestRecordService();

  List<ContestRecord> upsert(
    List<ContestRecord> records,
    ContestRecord record,
  ) {
    final next = [
      for (final item in records)
        if (item.id != record.id) item,
      record,
    ];
    return sortByDateDescending(next);
  }

  List<ContestRecord> remove(List<ContestRecord> records, String id) {
    return sortByDateDescending(
      records.where((record) => record.id != id).toList(),
    );
  }

  List<ContestRecord> sortByDateDescending(List<ContestRecord> records) {
    final sorted = [...records]..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) {
          return byDate;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
    return List.unmodifiable(sorted);
  }

  List<ContestRecord> filterByDateRange(
    List<ContestRecord> records, {
    String? startDate,
    String? endDate,
  }) {
    return sortByDateDescending(records.where((record) {
      if (startDate != null && record.date.compareTo(startDate) < 0) {
        return false;
      }
      if (endDate != null && record.date.compareTo(endDate) > 0) {
        return false;
      }
      return true;
    }).toList());
  }

  List<ContestRankPoint> buildRankPoints(List<ContestRecord> records) {
    final sorted = [...records]..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) {
          return byDate;
        }
        return a.updatedAt.compareTo(b.updatedAt);
      });
    return List.unmodifiable([
      for (final record in sorted)
        ContestRankPoint(
          record: record,
          date: DateTime.parse(record.date),
          rank: record.rank,
        ),
    ]);
  }
}
