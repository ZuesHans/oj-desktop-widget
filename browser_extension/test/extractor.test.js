"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const extractor = require("../extractor.js");

const cases = [
  ["https://codeforces.com/contest/1799/problem/A", "cf", "1799:A"],
  ["https://codeforces.com/problemset/problem/1799/A?locale=en", "cf", "1799:A"],
  ["https://atcoder.jp/contests/abc300/tasks/abc300_a", "atcoder", "abc300_a"],
  ["https://atcoder.jp/contests/custom/tasks/A", "atcoder", "custom:A"],
  ["https://www.luogu.com.cn/problem/P1001", "lg", "P1001"],
  ["https://ac.nowcoder.com/acm/problem/12345", "nc", "12345"],
  ["https://leetcode.cn/problems/two-sum/", "lccn", "two-sum"],
  ["https://acm.hdu.edu.cn/showproblem.php?pid=1000", "hd", "1000"],
  ["https://acm.hdu.edu.cn/contest/problem?cid=1237&pid=1007", "hd", "1237:1007"],
  ["http://poj.org/problem?id=1000", "poj", "1000"],
  ["https://onlinejudge.org/index.php?option=onlinejudge&page=show_problem&problem=36", "uva", "36"],
  ["https://onlinejudge.org/problem/36", "uva", "36"]
];

for (const [url, platform, externalId] of cases) {
  assert.equal(extractor.detectPlatform(url), platform);
  assert.equal(extractor.extractExternalId(url, platform), externalId);
}

assert.deepEqual(
  extractor.buildPayload({
    url: cases[0][0],
    title: " A. Test ",
    tags: ["math", "math", " implementation "],
    difficulty: " 800 "
  }),
  {
    url: cases[0][0],
    title: "A. Test",
    platform: "cf",
    externalId: "1799:A",
    tags: ["math", "implementation"],
    difficulty: "800"
  }
);

const manifestPath = path.join(__dirname, "..", "manifest.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
assert.equal(manifest.manifest_version, 3);
assert.ok(!manifest.permissions.includes("cookies"));
assert.deepEqual(manifest.host_permissions, ["http://127.0.0.1:27121/*"]);

console.log(`extractor fixtures passed: ${cases.length}`);
