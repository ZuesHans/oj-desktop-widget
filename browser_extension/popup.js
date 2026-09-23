"use strict";

const tokenInput = document.getElementById("token");
const importButton = document.getElementById("import");
const statusText = document.getElementById("status");

chrome.storage.local.get(["pairingToken"], ({ pairingToken }) => {
  tokenInput.value = pairingToken || "";
});

tokenInput.addEventListener("change", () => {
  chrome.storage.local.set({ pairingToken: tokenInput.value.trim() });
});

importButton.addEventListener("click", async () => {
  const token = tokenInput.value.trim();
  if (!token) {
    statusText.textContent = "请先填写桌面端设置页中的配对令牌。";
    return;
  }
  importButton.disabled = true;
  statusText.textContent = "正在读取当前页面...";
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!tab || !tab.id || !/^https?:/.test(tab.url || "")) {
      throw new Error("当前页面不是 HTTP/HTTPS 题目页面。");
    }
    const [{ result: page }] = await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: () => {
        const text = (selector) =>
          document.querySelector(selector)?.textContent?.trim() || "";
        const meta = (name) =>
          document.querySelector(`meta[name="${name}"]`)?.content?.trim() || "";
        const tags = [
          ...document.querySelectorAll(
            ".tag-box, .problem-tag, [data-cy=topic-tag], [data-tag]"
          )
        ].map((node) => node.textContent?.trim() || "");
        const keywords = meta("keywords").split(",");
        return {
          url: location.href,
          title: text(".problem-statement .title") || text("h1") || document.title,
          tags: [...tags, ...keywords],
          difficulty:
            text("[diff], [data-difficulty], .difficulty") ||
            meta("difficulty")
        };
      }
    });
    const payload = OjFloatExtractor.buildPayload(page);
    const response = await fetch("http://127.0.0.1:27121/v1/problems/import", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${token}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify(payload)
    });
    const body = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(body.message || body.error || `HTTP ${response.status}`);
    }
    await chrome.storage.local.set({ pairingToken: token });
    statusText.textContent = body.status === "created"
      ? "已加入 OJ Float。"
      : "题目已存在，元数据已合并。";
  } catch (error) {
    statusText.textContent = `导入失败：${error.message || error}`;
  } finally {
    importButton.disabled = false;
  }
});
