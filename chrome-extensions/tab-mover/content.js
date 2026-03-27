function sendMsg(msg) {
  try { chrome.runtime.sendMessage(msg); } catch (e) {}
}

const reorderKeys = {
  KeyH: -1, KeyL: 1,
  KeyY: "first", KeyO: "last",
  KeyU: -3, KeyI: 3,
};

const followDirKeys = {
  ArrowLeft: "left", ArrowRight: "right",
  ArrowUp: "up", ArrowDown: "down",
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

  if (e.ctrlKey && e.altKey && !e.metaKey) {
    const dir = followDirKeys[e.key];
    if (dir) {
      e.preventDefault();
      sendMsg({ action: "moveTabFollow", direction: dir });
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
