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
    }
  }
});
