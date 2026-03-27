function sendMsg(msg) {
  try { chrome.runtime.sendMessage(msg); } catch (e) {}
}

const reorderKeys = {
  KeyH: -1, KeyL: 1,
  KeyY: "first", KeyO: "last",
  KeyU: -3, KeyI: 3,
};

document.addEventListener("keydown", (e) => {
  if (e.metaKey && e.ctrlKey && e.shiftKey) {
    if (e.code === "Semicolon") {
      e.preventDefault();
      sendMsg({ action: "duplicateTab" });
    } else if (e.code === "Digit0") {
      e.preventDefault();
      sendMsg({ action: "detachTab" });
    }
  }

  if (e.metaKey && e.ctrlKey) {
    const step = reorderKeys[e.code];
    if (step !== undefined) {
      e.preventDefault();
      sendMsg({ action: "reorderTab", step, wrap: !e.shiftKey });
    }
  }
});
