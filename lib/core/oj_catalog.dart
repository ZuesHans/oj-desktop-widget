import '../models/oj_meta.dart';

const supportedOjs = <OjMeta>[
  OjMeta(
    id: 'codeforces',
    name: 'Codeforces',
    hint: 'handle',
    profileBaseUrl: 'https://codeforces.com/profile/',
  ),
  OjMeta(
    id: 'leetcode',
    name: 'LeetCode',
    hint: 'username',
    profileBaseUrl: 'https://leetcode.com/',
  ),
  OjMeta(
    id: 'atcoder',
    name: 'AtCoder',
    hint: 'username',
    profileBaseUrl: 'https://atcoder.jp/users/',
  ),
  OjMeta(
    id: 'luogu',
    name: '洛谷',
    hint: '用户名 / UID',
    profileBaseUrl: 'https://www.luogu.com.cn/user/',
  ),
  OjMeta(
    id: 'nowcoder',
    name: '牛客',
    hint: '用户名 / 用户 ID',
    profileBaseUrl: 'https://www.nowcoder.com/users/',
  ),
];
