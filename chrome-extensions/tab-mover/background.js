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

async function findWindowInDirection(direction) {
  const currentWindow = await chrome.windows.getCurrent();
  const allWindows = await chrome.windows.getAll({ windowTypes: ["normal"] });
  const displayBounds = await getVisibleDisplayBounds();

  const candidates = allWindows.filter(
    (w) => w.id !== currentWindow.id && isWindowOnScreen(w, displayBounds)
  );

  if (candidates.length === 0) return null;

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

  return bestWindow;
}

async function moveTabInDirection(direction) {
  const targetWindow = await findWindowInDirection(direction);
  if (!targetWindow) return;

  const [activeTab] = await chrome.tabs.query({
    active: true,
    currentWindow: true,
  });

  if (!activeTab) return;

  await chrome.tabs.move(activeTab.id, {
    windowId: targetWindow.id,
    index: -1,
  });
  await chrome.tabs.update(activeTab.id, { active: true });
}

async function reorderTab(direction, wrap) {
  const [activeTab] = await chrome.tabs.query({
    active: true,
    currentWindow: true,
  });
  if (!activeTab) return;

  const tabs = await chrome.tabs.query({ currentWindow: true });
  const newIndex = direction === "left" ? activeTab.index - 1 : activeTab.index + 1;

  if (newIndex >= 0 && newIndex < tabs.length) {
    await chrome.tabs.move(activeTab.id, { index: newIndex });
    return;
  }

  if (!wrap) return;

  const targetWindow = await findWindowInDirection(direction);
  if (!targetWindow) return;

  const targetIndex = direction === "left" ? -1 : 0;
  await chrome.tabs.move(activeTab.id, {
    windowId: targetWindow.id,
    index: targetIndex,
  });
  await chrome.tabs.update(activeTab.id, { active: true });
  await chrome.windows.update(targetWindow.id, { focused: true });
}

chrome.commands.onCommand.addListener(async (command) => {
  const direction = command.replace("move-tab-", "");
  await moveTabInDirection(direction);
});

chrome.runtime.onMessage.addListener((msg) => {
  if (msg.action === "duplicateTab") {
    chrome.tabs.query({ active: true, currentWindow: true }, ([tab]) => {
      if (tab) chrome.tabs.duplicate(tab.id);
    });
  } else if (msg.action === "detachTab") {
    chrome.tabs.query({ active: true, currentWindow: true }, ([tab]) => {
      if (tab) chrome.windows.create({ tabId: tab.id });
    });
  } else if (msg.action === "reorderTabLeft") {
    reorderTab("left", false);
  } else if (msg.action === "reorderTabRight") {
    reorderTab("right", false);
  } else if (msg.action === "reorderWrapTabLeft") {
    reorderTab("left", true);
  } else if (msg.action === "reorderWrapTabRight") {
    reorderTab("right", true);
  }
});
