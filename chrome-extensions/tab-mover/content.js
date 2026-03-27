function sendMsg(msg) {
  try { chrome.runtime.sendMessage(msg); } catch (e) {}
}

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

  if (e.metaKey && e.ctrlKey && !e.shiftKey) {
    if (e.code === "KeyH") {
      e.preventDefault();
      sendMsg({ action: "reorderTabLeft" });
    } else if (e.code === "KeyL") {
      e.preventDefault();
      sendMsg({ action: "reorderTabRight" });
    } else if (e.code === "KeyY") {
      e.preventDefault();
      sendMsg({ action: "reorderTabToFirst" });
    } else if (e.code === "KeyO") {
      e.preventDefault();
      sendMsg({ action: "reorderTabToLast" });
    } else if (e.code === "KeyI") {
      e.preventDefault();
      sendMsg({ action: "reorderTab3Right" });
    } else if (e.code === "KeyP") {
      e.preventDefault();
      sendMsg({ action: "reorderTab3Left" });
    }
  }
});
