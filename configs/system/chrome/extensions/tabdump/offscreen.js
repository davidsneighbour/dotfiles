function copyWithExecCommand(text) {
  const textarea = document.createElement("textarea");

  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.left = "-9999px";
  textarea.style.top = "0";

  document.body.appendChild(textarea);

  try {
    textarea.focus();
    textarea.select();
    textarea.setSelectionRange(0, textarea.value.length);

    const copied = document.execCommand("copy");

    if (!copied) {
      throw new Error('document.execCommand("copy") returned false.');
    }
  } finally {
    textarea.remove();
  }
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type !== "COPY_TO_CLIPBOARD") {
    return undefined;
  }

  try {
    if (typeof message.text !== "string") {
      throw new TypeError("Clipboard payload must be a string.");
    }

    copyWithExecCommand(message.text);
    sendResponse({ ok: true });
  } catch (error) {
    console.error("Tabdump: clipboard write failed:", error);

    sendResponse({
      ok: false,
      error: error instanceof Error ? error.message : String(error),
    });
  }

  return undefined;
});
