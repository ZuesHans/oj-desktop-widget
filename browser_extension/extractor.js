(function (root) {
  "use strict";

  function cleanHost(url) {
    try {
      return new URL(url).hostname.toLowerCase().replace(/^www\./, "");
    } catch (_) {
      return "";
    }
  }

  function detectPlatform(url) {
    const host = cleanHost(url);
    if (host === "codeforces.com") return "cf";
    if (host === "atcoder.jp") return "atcoder";
    if (host === "luogu.com.cn") return "lg";
    if (host === "ac.nowcoder.com" || host.endsWith(".nowcoder.com")) {
      return "nc";
    }
    if (host === "leetcode.cn" || host.endsWith(".leetcode.cn")) {
      return "lccn";
    }
    if (host === "hdu.edu.cn" || host === "acm.hdu.edu.cn") return "hd";
    if (host === "poj.org" || host === "poj.org.cn") return "poj";
    if (host.includes("onlinejudge.org")) return "uva";
    if (host === "spoj.com" || host.endsWith(".spoj.com")) return "spoj";
    return "other";
  }

  function extractExternalId(url, platform) {
    let parsed;
    try {
      parsed = new URL(url);
    } catch (_) {
      return "";
    }
    const parts = parsed.pathname.split("/").filter(Boolean);
    const after = (name) => {
      const index = parts.indexOf(name);
      return index >= 0 && index + 1 < parts.length ? parts[index + 1] : "";
    };
    if (platform === "cf") {
      const contest = parts.indexOf("contest");
      const problem = parts.indexOf("problem");
      if (contest >= 0 && problem > contest && problem + 1 < parts.length) {
        return `${parts[contest + 1]}:${parts[problem + 1]}`;
      }
      const problemset = parts.indexOf("problemset");
      if (problemset >= 0 && parts[problemset + 1] === "problem") {
        return `${parts[problemset + 2] || ""}:${parts[problemset + 3] || ""}`;
      }
    }
    if (platform === "atcoder") return after("tasks");
    if (platform === "lg" || platform === "nc") return after("problem");
    if (platform === "lccn") return after("problems");
    if (platform === "hd") return parsed.searchParams.get("pid") || "";
    if (platform === "poj") return parsed.searchParams.get("id") || "";
    return "";
  }

  function buildPayload(page) {
    const platform = detectPlatform(page.url);
    const tags = Array.from(new Set((page.tags || []).map(String)
      .map((item) => item.trim()).filter(Boolean))).slice(0, 30);
    return {
      url: page.url,
      title: String(page.title || "").trim(),
      platform,
      externalId: extractExternalId(page.url, platform),
      tags,
      difficulty: String(page.difficulty || "").trim()
    };
  }

  const api = { detectPlatform, extractExternalId, buildPayload };
  root.OjFloatExtractor = api;
  if (typeof module !== "undefined" && module.exports) module.exports = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
