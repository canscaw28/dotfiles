document.addEventListener("keydown", (e) => {
  if (e.metaKey && e.ctrlKey && e.shiftKey) {
    if (e.code === "Semicolon") {
      e.preventDefault();
      chrome.runtime.sendMessage({ action: "duplicateTab" });
    } else if (e.code === "Digit0") {
      e.preventDefault();
      chrome.runtime.sendMessage({ action: "detachTab" });
    }
  }
});
