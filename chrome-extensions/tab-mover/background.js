chrome.commands.onCommand.addListener(async (command) => {
  const direction = command.replace("move-tab-", "");

  const currentWindow = await chrome.windows.getCurrent();
  const allWindows = await chrome.windows.getAll({ windowTypes: ["normal"] });

  if (allWindows.length < 2) return;

  const srcCX = currentWindow.left + currentWindow.width / 2;
  const srcCY = currentWindow.top + currentWindow.height / 2;

  let bestWindow = null;
  let bestDist = Infinity;

  for (const w of allWindows) {
    if (w.id === currentWindow.id) continue;

    const cx = w.left + w.width / 2;
    const cy = w.top + w.height / 2;
    const dx = cx - srcCX;
    const dy = cy - srcCY;

    let valid = false;
    let dist = 0;

    switch (direction) {
      case "right": valid = dx > 0; dist = dx; break;
      case "left":  valid = dx < 0; dist = -dx; break;
      case "down":  valid = dy > 0; dist = dy; break;
      case "up":    valid = dy < 0; dist = -dy; break;
    }

    if (valid && dist < bestDist) {
      bestDist = dist;
      bestWindow = w;
    }
  }

  if (!bestWindow) return;

  const [activeTab] = await chrome.tabs.query({
    active: true,
    currentWindow: true,
  });

  if (activeTab) {
    await chrome.tabs.move(activeTab.id, {
      windowId: bestWindow.id,
      index: -1,
    });
    await chrome.tabs.update(activeTab.id, { active: true });
    await chrome.windows.update(bestWindow.id, { focused: true });
  }
});
