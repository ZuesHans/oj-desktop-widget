import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:oj_float/services/clipboard_problem_link.dart';
import 'package:oj_float/ui/problems/quick_entry_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const urlKey = ValueKey('quick-entry-url');

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('recognizes supported problem URLs embedded in copied text', () {
    for (final link in [
      'https://codeforces.com/problemset/problem/2000/A',
      'https://www.codeforces.com/contest/2000/problem/B',
      'https://codeforces.com/gym/100001/problem/A',
      'https://atcoder.jp/contests/abc300/tasks/abc300_a',
      'https://www.luogu.com.cn/problem/P1001',
      'https://leetcode.cn/problems/two-sum/description/',
      'https://leetcode.com/problems/two-sum/',
      'https://ac.nowcoder.com/acm/problem/1000',
      'https://ac.nowcoder.com/acm/contest/1000/A',
      'https://www.nowcoder.com/practice/abcdef1234',
      'http://acm.hdu.edu.cn/showproblem.php?pid=1000',
      'http://poj.org/problem?id=1000',
      'https://onlinejudge.org/index.php?option=com_onlinejudge&problem=123',
      'https://onlinejudge.org/external/1/100.html',
      'https://www.spoj.com/problems/TEST/',
    ]) {
      expect(findClipboardProblemLink('题目：[链接]($link)。'), link, reason: link);
    }
    expect(
        findClipboardProblemLink(
            'https://example.com/a https://luogu.com.cn/problem/P1001'),
        'https://luogu.com.cn/problem/P1001');
  });

  test('ignores ordinary text, profile pages, credentials and lookalike hosts',
      () {
    for (final text in [
      '',
      'my private notes',
      'https://example.com/problem/P1001',
      'https://codeforces.com/profile/tourist',
      'https://luogu.com.cn/',
      'https://codeforces.com.evil.test/problemset/problem/2000/A',
      'https://user:secret@luogu.com.cn/problem/P1001',
      'file:///C:/problem.html',
      'https://poj.org/problem?id=oops',
      'https://notonlinejudge.org/?problem=1',
    ]) {
      expect(findClipboardProblemLink(text), isNull, reason: text);
    }
  });

  testWidgets('opening pre-fills a link without fetching or saving; Esc closes',
      (tester) async {
    var parses = 0;
    var saves = 0;
    var closes = 0;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {'text': 'https://luogu.com.cn/problem/P1001'};
      }
      return null;
    });
    await tester.pumpWidget(MaterialApp(
        home: QuickEntryView(
      onParse: (url) async {
        parses++;
        return ParsedProblemLink(
            title: 'A+B', url: url, platform: ProblemPlatform.lg);
      },
      onSave: (_) async {
        saves++;
      },
      onClose: () {
        closes++;
      },
    )));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(urlKey)).controller!.text,
        'https://luogu.com.cn/problem/P1001');
    expect(find.text('已从剪贴板填入题目链接'), findsOneWidget);
    expect(parses, 0);
    expect(saves, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(closes, 1);
  });

  testWidgets(
      'a slow clipboard result cannot overwrite user input, even after clearing',
      (tester) async {
    final pending = Completer<Object?>();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return pending.future;
      return null;
    });
    await tester.pumpWidget(MaterialApp(
        home: QuickEntryView(
      onParse: (_) async => throw StateError('must not parse'),
      onSave: (_) async {},
      onClose: () {},
    )));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(urlKey), 'my link');
    await tester.enterText(find.byKey(urlKey), '');
    pending.complete({'text': 'https://luogu.com.cn/problem/P1001'});
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byKey(urlKey)).controller!.text, isEmpty);
    expect(find.text('已从剪贴板填入题目链接'), findsNothing);
  });

  testWidgets(
      'unavailable clipboard stays editable and Esc cannot interrupt parsing',
      (tester) async {
    var closes = 0;
    final parsed = Completer<ParsedProblemLink>();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        throw PlatformException(code: 'denied');
      }
      return null;
    });
    await tester.pumpWidget(MaterialApp(
        home: QuickEntryView(
      onParse: (_) => parsed.future,
      onSave: (_) async {},
      onClose: () {
        closes++;
      },
    )));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(urlKey), 'https://luogu.com.cn/problem/P1001');
    await tester.tap(find.text('解析'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closes, 0);
    parsed.complete(const ParsedProblemLink(
        title: 'A+B',
        url: 'https://luogu.com.cn/problem/P1001',
        platform: ProblemPlatform.lg));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(closes, 1);
  });

  testWidgets('closing and reopening quick entry reads the latest clipboard',
      (tester) async {
    var link = 'https://luogu.com.cn/problem/P1001';
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': link};
      return null;
    });
    await tester.binding.setSurfaceSize(const Size(1120, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const OjFloatApp(
        enablePlatformIntegration: false, autoInitializeController: false));
    await tester.pumpAndSettle();
    for (final next in [
      'https://luogu.com.cn/problem/P1001',
      'https://leetcode.cn/problems/two-sum/'
    ]) {
      link = next;
      await tester.tap(find.byTooltip('快速录入 (Ctrl+Shift+O)'));
      await tester.pumpAndSettle();
      expect(
          tester.widget<TextField>(find.byKey(urlKey)).controller!.text, next);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(urlKey), findsNothing);
      expect(find.byKey(const ValueKey('dashboard-shell')), findsOneWidget);
    }
  });
}
