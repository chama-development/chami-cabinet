import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { htmlPreviewText } from "./htmlPreview";

describe("HTML preview text", () => {
  it("extracts formatted text and decodes entities", () => {
    expect(htmlPreviewText("<b>Save &amp; renew</b>\n<i>Today</i>"))
      .toBe("Save & renew\nToday");
  });

  it("keeps decoded markup inert when rendered by React", () => {
    const { container } = render(<pre>{htmlPreviewText(
      '&lt;img src=x onerror="alert(1)"&gt;<img src=x onerror="alert(2)">',
    )}</pre>);
    expect(screen.getByText('<img src=x onerror="alert(1)">')).toBeInTheDocument();
    expect(container.querySelector("img")).toBeNull();
  });
});
