// ==UserScript==
// @name         OJ Float 猪猪一键存题
// @namespace    https://github.com/ZuesHans/oj-desktop-widget
// @version      1.1.0
// @description  点击猪猪按钮，把当前题目或链接存入 OJ Float 题库。
// @author       zueshans
// @match        http://*/*
// @match        https://*/*
// @connect      127.0.0.1
// @grant        GM_registerMenuCommand
// @grant        GM_xmlhttpRequest
// @run-at       document-idle
// @noframes
// @icon         __PIG_ICON_DATA_URL__
// ==/UserScript==

(function (root, factory) {
  "use strict";

  const api = factory();
  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
    return;
  }
  api.install();
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  "use strict";

  const endpoint = "http://127.0.0.1:27122/v1/problems/import";
  const iconDataUrl = "__PIG_ICON_DATA_URL__";
  const uiId = "oj-float-pig-importer";
  let busy = false;
  let button;
  let icon;
  let status;
  let hideTimer;

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
    if (platform === "atcoder") {
      const taskIndex = parts.indexOf("tasks");
      if (taskIndex >= 0 && taskIndex + 1 < parts.length) {
        const task = parts[taskIndex + 1];
        const contestIndex = parts.indexOf("contests");
        if (contestIndex >= 0 && contestIndex + 1 < parts.length) {
          const contest = parts[contestIndex + 1];
          const normalizedContest = contest.toLowerCase();
          const normalizedTask = task.toLowerCase();
          if (normalizedTask !== normalizedContest &&
              !normalizedTask.startsWith(`${normalizedContest}_`)) {
            return `${contest}:${task}`;
          }
        }
        return task;
      }
      return "";
    }
    if (platform === "lg" || platform === "nc") return after("problem");
    if (platform === "lccn") return after("problems");
    if (platform === "hd") {
      const cid = parsed.searchParams.get("cid") || "";
      const pid = parsed.searchParams.get("pid") || "";
      const contest = parts.indexOf("contest");
      const isContestProblem = contest >= 0 &&
        parts[contest + 1]?.toLowerCase() === "problem";
      return isContestProblem && cid && pid ? `${cid}:${pid}` : pid;
    }
    if (platform === "poj") return parsed.searchParams.get("id") || "";
    if (platform === "uva") {
      const problem = parsed.searchParams.get("problem") || "";
      if (problem) return problem;
      const problemIndex = parts.indexOf("problem");
      if (problemIndex >= 0 && problemIndex + 1 < parts.length) {
        return parts[problemIndex + 1];
      }
      const external = parts.indexOf("external");
      if (external >= 0 && external + 2 < parts.length) {
        const volume = parts[external + 1];
        const number = parts[external + 2].replace(/\.[^.]+$/, "");
        if (volume && number) return `${volume}:${number}`;
      }
    }
    return "";
  }

  function normalizedStrings(values, limit) {
    return Array.from(new Set((values || []).map(String)
      .map((value) => value.trim()).filter(Boolean))).slice(0, limit);
  }

  function buildPayload(page) {
    const url = String(page.url || "").trim();
    const platform = detectPlatform(url);
    return {
      url,
      title: String(page.title || "").trim().slice(0, 500),
      platform,
      externalId: extractExternalId(url, platform).slice(0, 200),
      tags: normalizedStrings(page.tags, 30)
        .map((tag) => tag.slice(0, 100)),
      difficulty: String(page.difficulty || "").trim().slice(0, 100)
    };
  }

  function collectPage(pageDocument, pageLocation) {
    const text = (...selectors) => {
      for (const selector of selectors) {
        const value = pageDocument.querySelector(selector)
          ?.textContent?.trim() || "";
        if (value) return value;
      }
      return "";
    };
    const meta = (selector) =>
      pageDocument.querySelector(selector)?.content?.trim() || "";
    const tagNodes = pageDocument.querySelectorAll(
      ".tag-box, .problem-tag, [data-cy=topic-tag], [data-tag]"
    );
    const tags = Array.from(tagNodes)
      .map((node) => node.textContent?.trim() || "");
    tags.push(...meta('meta[name="keywords"]').split(","));

    return {
      url: pageLocation.href,
      title: text(
        ".problem-statement .title",
        "[data-cy=question-title]",
        ".problem-title",
        "#task-statement .h2",
        "h1"
      ) || meta('meta[property="og:title"]') || pageDocument.title || "",
      tags,
      difficulty: text(
        "[data-difficulty]",
        "[diff]",
        ".difficulty"
      ) || meta('meta[name="difficulty"]')
    };
  }

  function explainFailure(statusCode, body) {
    if (statusCode === 401) {
      return "C++ 小程序拒绝了导入请求，请更新油猴脚本。";
    }
    if (statusCode === 0) {
      return "连接不到题库，请先启动 OJ 题库 C++ 小程序。";
    }
    return body?.message || body?.error || `本地服务返回 HTTP ${statusCode}`;
  }

  function requestImport(payload) {
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method: "POST",
        url: endpoint,
        headers: {
          "Content-Type": "application/json",
          "X-OJ-Companion": "userscript-v1"
        },
        data: JSON.stringify(payload),
        timeout: 10000,
        onload(response) {
          let body = {};
          try {
            body = JSON.parse(response.responseText || "{}");
          } catch (_) {
            // The status code remains enough to report a useful error.
          }
          if (response.status >= 200 && response.status < 300) {
            resolve(body);
            return;
          }
          reject(new Error(explainFailure(response.status, body)));
        },
        ontimeout() {
          reject(new Error("连接题库超时，请确认 C++ 小程序正在运行。"));
        },
        onerror() {
          reject(new Error(explainFailure(0, {})));
        }
      });
    });
  }

  function showStatus(message, kind = "info") {
    if (!status) return;
    window.clearTimeout(hideTimer);
    status.textContent = message;
    status.dataset.kind = kind;
    status.style.background = kind === "success"
      ? "#166534"
      : kind === "error" ? "#991b1b" : "#183153";
    status.style.opacity = "1";
    status.style.transform = "translateY(0)";
    hideTimer = window.setTimeout(() => {
      status.style.opacity = "0";
      status.style.transform = "translateY(6px)";
    }, kind === "error" ? 6500 : 3500);
  }

  function setBusy(value) {
    busy = value;
    if (!button || !icon) return;
    button.disabled = value;
    button.style.cursor = value ? "wait" : "pointer";
    icon.style.transform = value ? "scale(.82)" : "scale(1)";
    icon.style.opacity = value ? ".65" : "1";
  }

  async function saveCurrentPage() {
    if (busy) return;
    setBusy(true);
    try {
      const payload = buildPayload(collectPage(document, window.location));
      if (!/^https?:\/\//i.test(payload.url)) {
        throw new Error("当前页面不是可以保存的 HTTP/HTTPS 链接。");
      }
      showStatus("猪猪正在存题…");
      const result = await requestImport(payload);
      showStatus(
        result.status === "created"
          ? "已存入题库 ✓"
          : "题目已存在，信息已合并 ✓",
        "success"
      );
    } catch (error) {
      showStatus(`保存失败：${error.message || error}`, "error");
    } finally {
      setBusy(false);
    }
  }

  function createUi() {
    if (document.getElementById(uiId)) return;
    const host = document.createElement("div");
    host.id = uiId;
    host.style.cssText = [
      "all:initial",
      "position:fixed",
      "right:22px",
      "bottom:22px",
      "z-index:2147483647"
    ].join(";");
    const shadow = host.attachShadow({ mode: "closed" });

    status = document.createElement("div");
    status.setAttribute("role", "status");
    status.style.cssText = [
      "position:absolute",
      "right:0",
      "bottom:68px",
      "box-sizing:border-box",
      "width:max-content",
      "max-width:min(320px,calc(100vw - 44px))",
      "padding:9px 12px",
      "border-radius:10px",
      "color:#fff",
      "font:600 13px/1.45 'Segoe UI',sans-serif",
      "box-shadow:0 8px 24px rgba(15,23,42,.24)",
      "opacity:0",
      "transform:translateY(6px)",
      "transition:opacity .16s ease,transform .16s ease",
      "pointer-events:none"
    ].join(";");

    button = document.createElement("button");
    button.type = "button";
    button.title = "存入 OJ Float 题库";
    button.setAttribute("aria-label", "存入 OJ Float 题库");
    button.style.cssText = [
      "all:initial",
      "display:grid",
      "place-items:center",
      "box-sizing:border-box",
      "width:58px",
      "height:58px",
      "border:2px solid rgba(255,255,255,.95)",
      "border-radius:50%",
      "background:#fff4ef",
      "box-shadow:0 7px 22px rgba(54,32,24,.28)",
      "cursor:pointer",
      "transition:transform .16s ease,box-shadow .16s ease"
    ].join(";");
    button.addEventListener("mouseenter", () => {
      if (!busy) button.style.transform = "translateY(-2px) scale(1.04)";
    });
    button.addEventListener("mouseleave", () => {
      button.style.transform = "none";
    });
    button.addEventListener("click", saveCurrentPage);

    icon = document.createElement("img");
    icon.src = iconDataUrl;
    icon.alt = "";
    icon.style.cssText = [
      "display:block",
      "width:50px",
      "height:50px",
      "object-fit:contain",
      "transition:transform .16s ease,opacity .16s ease",
      "pointer-events:none"
    ].join(";");
    icon.addEventListener("error", () => {
      icon.remove();
      button.textContent = "🐷";
      button.style.font = "36px/1 'Segoe UI Emoji',sans-serif";
    });
    button.appendChild(icon);
    shadow.append(status, button);
    document.documentElement.appendChild(host);
  }

  function install() {
    createUi();
    GM_registerMenuCommand("保存当前题目", saveCurrentPage);
  }

  return {
    buildPayload,
    cleanHost,
    collectPage,
    detectPlatform,
    explainFailure,
    extractExternalId,
    install,
    normalizedStrings
  };
});
