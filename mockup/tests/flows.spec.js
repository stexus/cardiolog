import { test, expect } from "@playwright/test";
test.beforeEach(async ({ page }) => {
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Norwegian 4×4", exact: true }),
  ).toBeVisible();
});
test("template validation, settings scope, pause, partial save and persistence", async ({
  page,
}) => {
  await page.getByRole("button", { name: "Edit", exact: true }).click();
  await page.getByLabel("Work (seconds)", { exact: true }).fill("300");
  await expect(page.locator("#template-total")).toContainText("39:00");
  await page.getByRole("button", { name: "Save template" }).click();
  await page.getByRole("button", { name: "Start sample workout" }).click();
  await page.getByRole("button", { name: "Pause", exact: false }).click();
  const clock = await page.locator("#countdown").textContent();
  await page.waitForTimeout(1100);
  await expect(page.locator("#countdown")).toHaveText(clock);
  await page.getByRole("button", { name: "Edit Next", exact: true }).click();
  await page.getByLabel("Speed (mph)").fill("7.2");
  await page.getByLabel("Apply to").selectOption("next");
  await expect(page.locator("#affected")).toContainText("1");
  await page.getByRole("button", { name: "Apply settings" }).click();
  await page.getByRole("button", { name: "Finish", exact: true }).click();
  await page.getByRole("button", { name: "Finish & save sample" }).click();
  await expect(
    page.getByText("PARTIAL · SAMPLE", { exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("No HR recorded for this sample session."),
  ).toBeVisible();
  await page.reload();
  await page.getByRole("button", { name: "History", exact: true }).click();
  await expect(page.locator(".history-card")).toHaveCount(4);
});
test("all sample states, graph selection, copy configuration and layout modes", async ({
  page,
}) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  for (const id of [
    "work",
    "recovery",
    "paused",
    "no-hr",
    "disconnected",
    "empty",
    "completed",
    "partial",
    "ready",
  ]) {
    await page.locator("#preview-state").selectOption(id);
    await expect(page.locator("#screen")).not.toBeEmpty();
  }
  await page.locator("#preview-state").selectOption("completed");
  await page.getByRole("button", { name: /Work 2/ }).click();
  await expect(page.locator(".interval-row.chosen")).toContainText("Work 2");
  await page.getByRole("button", { name: "Copy Workout", exact: true }).click();
  await expect(page.locator("#copy-preview")).toContainText("SAMPLE DATA");
  await page.getByLabel("Gym & entered equipment settings").uncheck();
  await expect(page.locator("#copy-preview")).not.toContainText("mph");
  await page.getByRole("button", { name: "Close", exact: true }).click();
  await page.locator("#appearance").selectOption("dark");
  await page.locator("#orientation").selectOption("landscape");
  await page.locator("#screen").evaluate((e) => (e.scrollTop = 0));
  await page.screenshot({
    path: "../artifacts/browser-detail-dark-landscape.png",
    fullPage: true,
  });
  await page.locator("#orientation").selectOption("portrait");
  await page.locator("#appearance").selectOption("light");
  await page.locator("#preview-state").selectOption("paused");
  await page.locator("#orientation").selectOption("landscape");
  const finish = await page
    .getByRole("button", { name: "Finish", exact: true })
    .boundingBox();
  const screen = await page.locator("#screen").boundingBox();
  expect(finish.y + finish.height).toBeLessThanOrEqual(
    screen.y + screen.height,
  );
  await page.locator("#orientation").selectOption("portrait");
  await page.screenshot({
    path: "../artifacts/browser-paused-light-portrait.png",
    fullPage: true,
  });
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.getByRole("button", { name: "Resume" })).toBeVisible();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= window.innerWidth,
    ),
  ).toBeTruthy();
  expect(errors).toEqual([]);
});
test("bike equipment, added repetition and no future work", async ({
  page,
}) => {
  await page.getByRole("button", { name: "Back to Timers" }).click();
  await page.getByRole("button", { name: "Steady ride" }).click();
  await page.getByRole("button", { name: /Neighborhood gym/ }).click();
  await page.getByRole("button", { name: /Spin bike/ }).click();
  await page.getByRole("button", { name: "Start sample workout" }).click();
  await expect(page.getByText("ENTERED RESISTANCE")).toBeVisible();
  await page.getByRole("button", { name: "Add Interval" }).click();
  await expect(page.getByText("46:00 planned", { exact: true })).toBeVisible();
});

test("timer library, remembered edits and pinned Start across layouts", async ({
  page,
}) => {
  const start = page.getByRole("button", { name: "Start sample workout" });
  const expectPinned = async () => {
    const before = await start.boundingBox();
    const phone = await page.locator("#phone").boundingBox();
    expect(before.y + before.height).toBeLessThanOrEqual(
      phone.y + phone.height,
    );
    expect(before.y + before.height).toBeLessThanOrEqual(
      page.viewportSize().height,
    );
    await page
      .locator("#screen")
      .evaluate((e) => (e.scrollTop = e.scrollHeight));
    const after = await start.boundingBox();
    expect(after.y).toBe(before.y);
  };
  await expect(
    page.getByRole("button", { name: "Change template" }),
  ).toHaveCount(0);
  await expectPinned();
  await page.getByRole("button", { name: "Back to Timers" }).click();
  await expect(
    page.getByRole("heading", { name: "Timers", exact: true }),
  ).toBeVisible();
  await expect(start).toHaveCount(0);
  await page.getByRole("button", { name: /Steady ride/ }).click();
  await page.getByRole("button", { name: "Edit", exact: true }).click();
  await page.getByLabel("Name", { exact: true }).fill("My steady ride");
  await page.getByRole("button", { name: "Save template" }).click();
  await page.reload();
  await expect(
    page.getByRole("heading", { name: "My steady ride", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Timers", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Timers", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: /My steady ride/ }).click();
  await page.getByRole("button", { name: "History", exact: true }).click();
  await page.getByRole("button", { name: "Timers", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Timers", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: /My steady ride/ }).click();
  await page.locator("#orientation").selectOption("landscape");
  await expectPinned();
  await page.locator("#orientation").selectOption("portrait");
  await page.setViewportSize({ width: 900, height: 800 });
  await expectPinned();
  await page.setViewportSize({ width: 844, height: 390 });
  await expectPinned();
  await page.setViewportSize({ width: 390, height: 700 });
  await expectPinned();
  await page.getByRole("button", { name: "Back to Timers" }).click();
  await page.getByRole("button", { name: "New template", exact: true }).click();
  await page.getByLabel("Name", { exact: true }).fill("Canceled draft");
  await page.getByRole("button", { name: "Close", exact: true }).click();
  await expect(
    page.getByRole("button", { name: /Canceled draft/ }),
  ).toHaveCount(0);
  await page.getByRole("button", { name: /My steady ride/ }).click();
  await page
    .getByRole("button", { name: "Template options", exact: true })
    .click();
  await page
    .getByRole("button", { name: "Duplicate template", exact: true })
    .click();
  await page.getByRole("button", { name: "Save template" }).click();
  await page.reload();
  await expect(
    page.getByRole("heading", { name: "My steady ride copy", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Back to Timers" }).click();
  await expect(page.locator(".library-row")).toHaveCount(3);
});
