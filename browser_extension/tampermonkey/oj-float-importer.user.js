// ==UserScript==
// @name         OJ Float 猪猪一键存题
// @namespace    https://github.com/ZuesHans/oj-desktop-widget
// @version      1.0.0
// @description  点击猪猪按钮，把当前题目或链接存入 OJ Float 题库。
// @author       zueshans
// @match        http://*/*
// @match        https://*/*
// @connect      127.0.0.1
// @grant        GM_getValue
// @grant        GM_setValue
// @grant        GM_registerMenuCommand
// @grant        GM_xmlhttpRequest
// @run-at       document-idle
// @noframes
// @icon         data:image/png;base64,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
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

  const endpoint = "http://127.0.0.1:27121/v1/problems/import";
  const tokenKey = "ojFloatPairingToken";
  const iconDataUrl = "data:image/png;base64,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";
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
      return "配对令牌不正确，请从 OJ Float 设置页重新复制。";
    }
    if (statusCode === 0) {
      return "连接不到 OJ Float，请先启动桌面客户端。";
    }
    return body?.message || body?.error || `本地服务返回 HTTP ${statusCode}`;
  }

  function readToken() {
    return Promise.resolve(GM_getValue(tokenKey, ""))
      .then((value) => String(value || "").trim());
  }

  function writeToken(value) {
    return Promise.resolve(GM_setValue(tokenKey, value));
  }

  async function configureToken() {
    const current = await readToken();
    const value = window.prompt(
      "粘贴 OJ Float「设置 → 浏览器导入」里的配对令牌：",
      current
    );
    if (value === null) return "";
    const token = value.trim();
    if (!token) {
      showStatus("配对令牌不能为空。", "error");
      return "";
    }
    await writeToken(token);
    showStatus("配对令牌已保存。", "success");
    return token;
  }

  async function requireToken() {
    return (await readToken()) || configureToken();
  }

  function requestImport(payload, token) {
    return new Promise((resolve, reject) => {
      GM_xmlhttpRequest({
        method: "POST",
        url: endpoint,
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json"
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
          reject(new Error("连接 OJ Float 超时，请确认桌面客户端正在运行。"));
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
      const token = await requireToken();
      if (!token) return;
      const payload = buildPayload(collectPage(document, window.location));
      if (!/^https?:\/\//i.test(payload.url)) {
        throw new Error("当前页面不是可以保存的 HTTP/HTTPS 链接。");
      }
      showStatus("猪猪正在存题…");
      const result = await requestImport(payload, token);
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
    GM_registerMenuCommand("设置 OJ Float 配对令牌", configureToken);
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
