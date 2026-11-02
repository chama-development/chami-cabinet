/** Extract display text; callers still render it as an escaped React text node. */
export function htmlPreviewText(html: string): string {
  const document = new DOMParser().parseFromString(html, "text/html");
  return document.body.textContent ?? "";
}
