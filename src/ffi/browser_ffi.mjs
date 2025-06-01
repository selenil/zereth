/**
 * Hides the default browser drag image/ghost that appears when dragging elements.
 *
 * This is necessary because we want to handle the visual feedback of
 * dragging pieces ourselves. It works by creating a tiny 1x1px
 * invisible div element and setting that as the drag image instead of the
 * default one. The div is automatically cleaned up after the drag operation ends.
 *
 */
export function hideDragImage(event) {
  let ghostImage = document.createElement("div");
  ghostImage.style.width = "1px";
  ghostImage.style.height = "1px";
  ghostImage.style.position = "absolute";
  ghostImage.style.top = "-100px";
  document.body.appendChild(ghostImage);

  event.dataTransfer.setDragImage(ghostImage, 0, 0);

  function cleanup() {
    if (document.body.contains(ghostImage)) {
      document.body.removeChild(ghostImage);
    }
    event.target.removeEventListener("dragend", cleanup);
  }

  event.target.addEventListener("dragend", cleanup);
}

/**
 * Checks if debug mode is enabled via URL parameters
 * Returns true if ?debug=true is present in the URL
 */
export function isDebugMode() {
  const urlParams = new URLSearchParams(window.location.search);
  return urlParams.get("debug") === "true";
}

/**
 * Gets the current mouse position relative to an element
 */
export function getMousePosition(event) {
  return {
    x: event.clientX,
    y: event.clientY,
  };
}
