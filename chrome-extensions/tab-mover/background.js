async function getVisibleDisplayBounds() {
  const displays = await chrome.system.display.getInfo();
  return displays.map((d) => d.bounds);
}

function isWindowOnScreen(w, displayBounds) {
  const cx = w.left + w.width / 2;
  const cy = w.top + w.height / 2;
  return displayBounds.some(
    (d) =>
      cx >= d.left &&
      cx < d.left + d.width &&
      cy >= d.top &&
      cy < d.top + d.height
  );
}

async function moveTabInDirection(direction) {
  const currentWindow = await chrome.windows.getCurrent();
  const allWindows = await chrome.windows.getAll({ windowTypes: ["normal"] });
  const displayBounds = await getVisibleDisplayBounds();

  const candidates = allWindows.filter(
    (w) => w.id !== currentWindow.id && isWindowOnScreen(w, displayBounds)
  );

  if (candidates.length === 0) return;

  const srcCX = currentWindow.left + currentWindow.width / 2;
  const srcCY = currentWindow.top + currentWindow.height / 2;

  let bestWindow = null;
  let bestDist = Infinity;

  for (const w of candidates) {
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

  if (!activeTab) return;

  await chrome.tabs.move(activeTab.id, {
    windowId: bestWindow.id,
    index: -1,
  });
  await chrome.tabs.update(activeTab.id, { active: true });
}

chrome.commands.onCommand.addListener(async (command) => {
  const direction = command.replace("move-tab-", "");
  await moveTabInDirection(direction);
});
