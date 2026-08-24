const TAB_GROUP_ID_NONE = -1;

const ICONS = {
  copy: {
    16: "icons/copy-16.png",
    32: "icons/copy-32.png",
    48: "icons/copy-48.png",
    128: "icons/copy-128.png",
  },
  success: {
    16: "icons/check-copy-16.png",
    32: "icons/check-copy-32.png",
    48: "icons/check-copy-48.png",
    128: "icons/check-copy-128.png",
  },
};

async function showSuccessIndicator(count) {
  try {
    await chrome.action.setIcon({ path: ICONS.success });
    await chrome.action.setBadgeText({ text: String(count) });
    await chrome.action.setBadgeBackgroundColor({ color: "#15803d" });

    setTimeout(() => {
      Promise.all([
        chrome.action.setIcon({ path: ICONS.copy }),
        chrome.action.setBadgeText({ text: "" }),
      ]).catch((error) => {
        console.error("Tabdump: failed to reset success indicator:", error);
      });
    }, 2000);
  } catch (error) {
    console.error("Tabdump: failed to show success indicator:", error);
  }
}

async function showErrorIndicator(text) {
  try {
    await chrome.action.setBadgeText({ text });
    await chrome.action.setBadgeBackgroundColor({ color: "#b91c1c" });

    setTimeout(() => {
      chrome.action.setBadgeText({ text: "" }).catch((error) => {
        console.error("Tabdump: failed to clear error badge:", error);
      });
    }, 2000);
  } catch (error) {
    console.error("Tabdump: failed to show error indicator:", error);
  }
}

async function ensureOffscreenDocument() {
  const offscreenUrl = chrome.runtime.getURL("offscreen.html");

  if (typeof chrome.runtime.getContexts === "function") {
    const contexts = await chrome.runtime.getContexts({
      contextTypes: ["OFFSCREEN_DOCUMENT"],
      documentUrls: [offscreenUrl],
    });

    if (contexts.length > 0) {
      return;
    }
  }

  try {
    await chrome.offscreen.createDocument({
      url: "offscreen.html",
      reasons: ["CLIPBOARD"],
      justification: "Copy tab-group URLs to the clipboard.",
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);

    if (!message.toLowerCase().includes("single offscreen document")) {
      throw error;
    }
  }
}

async function copyText(text) {
  await ensureOffscreenDocument();

  try {
    const response = await chrome.runtime.sendMessage({
      type: "COPY_TO_CLIPBOARD",
      text,
    });

    if (!response?.ok) {
      throw new Error(response?.error || "Clipboard operation failed.");
    }
  } finally {
    try {
      await chrome.offscreen.closeDocument();
    } catch {
      // Ignore when the offscreen document has already gone away.
    }
  }
}

async function copyActiveGroupUrls() {
  try {
    const [activeTab] = await chrome.tabs.query({
      active: true,
      currentWindow: true,
    });

    if (!activeTab) {
      throw new Error("No active tab found.");
    }

    if (activeTab.groupId === TAB_GROUP_ID_NONE) {
      await showErrorIndicator("NO");
      console.warn("Tabdump: the active tab is not in a tab group.");
      return;
    }

    const tabs = await chrome.tabs.query({
      groupId: activeTab.groupId,
      windowId: activeTab.windowId,
    });

    const urls = tabs
      .map((tab) => tab.url)
      .filter((url) => typeof url === "string" && url.length > 0);

    if (urls.length === 0) {
      throw new Error("No readable URLs found in this tab group.");
    }

    await copyText(urls.join("\n"));
    await showSuccessIndicator(urls.length);

    console.info(`Tabdump: copied ${urls.length} URL(s).`);
  } catch (error) {
    console.error("Tabdump failed:", error);
    await showErrorIndicator("ERR");
  }
}

chrome.action.onClicked.addListener(() => {
  copyActiveGroupUrls().catch((error) => {
    console.error("Tabdump: unhandled error:", error);
  });
});
