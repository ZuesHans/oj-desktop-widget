"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const importer = require("../oj-float-importer.user.js");

const cases = [
  ["https://codeforces.com/contest/1799/problem/A", "cf", "1799:A"],
  ["https://atcoder.jp/contests/abc300/tasks/abc300_a", "atcoder", "abc300_a"],
  ["https://www.luogu.com.cn/problem/P1001", "lg", "P1001"],
  ["https://ac.nowcoder.com/acm/problem/12345", "nc", "12345"],
  ["https://leetcode.cn/problems/two-sum/", "lccn", "two-sum"],
  ["https://acm.hdu.edu.cn/showproblem.php?pid=1000", "hd", "1000"],
  ["http://poj.org/problem?id=1000", "poj", "1000"],
  ["https://onlinejudge.org/problem/36", "uva", "36"]
];

for (const [url, platform, externalId] of cases) {
  assert.equal(importer.detectPlatform(url), platform);
  assert.equal(importer.extractExternalId(url, platform), externalId);
}

assert.deepEqual(
  importer.buildPayload({
    url: "https://example.com/interesting/problem#section",
    title: " A page the parser does not know ",
    tags: ["graph", "graph", " shortest path "],
    difficulty: ""
  }),
  {
    url: "https://example.com/interesting/problem#section",
    title: "A page the parser does not know",
    platform: "other",
    externalId: "",
    tags: ["graph", "shortest path"],
    difficulty: ""
  }
);

assert.equal(
  importer.explainFailure(401, {}),
  "C++ 小程序拒绝了导入请求，请更新油猴脚本。"
);
assert.match(importer.explainFailure(0, {}), /启动 OJ 题库 C\+\+ 小程序/);

const scriptPath = path.join(__dirname, "..", "oj-float-importer.user.js");
const script = fs.readFileSync(scriptPath, "utf8");
assert.match(script, /@grant\s+GM_xmlhttpRequest/);
assert.match(script, /@connect\s+127\.0\.0\.1/);
assert.match(script, /@noframes/);
assert.match(script, /@icon\s+data:image\/png;base64,/);
assert.match(script, /127\.0\.0\.1:27122\/v1\/problems\/import/);
assert.match(script, /"X-OJ-Companion": "userscript-v1"/);
assert.doesNotMatch(script, /GM_getValue|GM_setValue|Authorization/);
assert.ok(!script.includes("__PIG_ICON_DATA_URL__"));

console.log(`tampermonkey importer fixtures passed: ${cases.length}`);
