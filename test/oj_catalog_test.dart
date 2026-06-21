import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  test('supported OJ labels are valid user-facing text', () {
    final labels = {
      for (final meta in supportedOjs) meta.id: '${meta.name}|${meta.hint}',
    };

    expect(labels['luogu'], '洛谷|用户名 / UID');
    expect(labels['nowcoder'], '牛客|用户名 / 用户 ID');
  });
}
