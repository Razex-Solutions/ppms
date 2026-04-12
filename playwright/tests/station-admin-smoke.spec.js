const { test, expect } = require('@playwright/test');

async function seedStationAdminSession(page, request) {
  const response = await request.post('http://127.0.0.1:8012/auth/login', {
    data: {
      username: 'stationadmin',
      password: 'station123',
    },
  });

  expect(response.ok()).toBeTruthy();
  const tokens = await response.json();

  await page.addInitScript((seededTokens) => {
    window.localStorage.setItem(
      'flutter.auth_tokens',
      JSON.stringify(JSON.stringify(seededTokens)),
    );
    window.localStorage.setItem('flutter.app_locale', JSON.stringify('en'));
  }, tokens);

  return tokens;
}

async function openStationAdminPage(page, request, hashRoute) {
  const tokens = await seedStationAdminSession(page, request);
  await page.goto('/#/workspace/station-admin', { waitUntil: 'load' });
  await expect(page.getByText('Open workflow').first()).toBeVisible({
    timeout: 120000,
  });
  if (hashRoute !== '#/workspace/station-admin') {
    await page.goto(`/${hashRoute}`, { waitUntil: 'load' });
  }
  return tokens;
}

test.describe('StationAdmin UI smoke', () => {
  test('updates fuel price with a required reason', async ({
    page,
    request,
  }) => {
    const uniqueSuffix = Date.now().toString().slice(-6);
    const reason = `Playwright UI smoke price update ${uniqueSuffix}`;
    const tokens = await openStationAdminPage(
      page,
      request,
      '#/workspace/station-admin/pricing',
    );
    const authToken = tokens.access_token ?? tokens.accessToken;

    await expect(page.getByText('Change price', { exact: true })).toBeVisible();
    const beforePricingText = await page.locator('body').innerText();
    const beforeHistoryCount =
      Number.parseInt(
        beforePricingText.match(/Recorded price changes\s+(\d+)/)?.[1] ?? '0',
        10,
      ) || 0;
    expect(beforeHistoryCount).toBeGreaterThan(0);

    await page.getByText('Change price', { exact: true }).click();
    await expect(page.getByText(/Change .* price/)).toBeVisible();

    const sellingPriceField = page.getByLabel('New selling price');
    const currentPrice = await sellingPriceField.inputValue();
    const nextPrice = (Number.parseFloat(currentPrice || '0') + 1).toFixed(2);

    await sellingPriceField.fill(nextPrice);
    await page.getByLabel('Reason').fill(reason);
    await page.getByLabel('Notes').fill('Automated StationAdmin smoke check');
    await page.getByText('Save', { exact: true }).click();

    await expect
      .poll(async () => {
        const text = await page.locator('body').innerText();
        return (
          Number.parseInt(
            text.match(/Recorded price changes\s+(\d+)/)?.[1] ?? '0',
            10,
          ) || 0
        );
      }, {
        timeout: 60000,
      })
      .toBe(beforeHistoryCount + 1);
  });

  test.skip('creates inventory item and tanker master data', async ({
    page,
    request,
  }) => {
    const uniqueSuffix = Date.now().toString().slice(-6);
    const itemName = `UI Lube ${uniqueSuffix}`;
    const itemCode = `UIL${uniqueSuffix}`;
    const tankerName = `UI Tanker ${uniqueSuffix}`;
    const tankerReg = `UI-${uniqueSuffix}`;
    const tokens = await openStationAdminPage(
      page,
      request,
      '#/workspace/station-admin/inventory',
    );
    const authToken = tokens.access_token ?? tokens.accessToken;
    expect(authToken).toBeTruthy();
    await expect(page.getByText('Add item', { exact: true })).toBeVisible();
    await page.getByText('Add item', { exact: true }).click();
    const itemInputs = page.locator('input');
    await expect(itemInputs).toHaveCount(7);
    await itemInputs.nth(0).fill(itemName);
    await itemInputs.nth(1).fill(itemCode);
    await itemInputs.nth(2).fill('Lubricant');
    await itemInputs.nth(3).fill('service_station');
    await itemInputs.nth(4).fill('1250');
    await itemInputs.nth(5).fill('950');
    await itemInputs.nth(6).fill('12');
    await page.getByText('Save', { exact: true }).click();

    await page.goto('/#/workspace/station-admin/tanker');
    await expect(page.getByText('Create tanker', { exact: true })).toBeVisible();
    await page.getByText('Create tanker', { exact: true }).click();

    const tankerInputs = page.locator('input');
    await expect(tankerInputs).toHaveCount(7);
    await tankerInputs.nth(0).fill(tankerReg);
    await tankerInputs.nth(1).fill(tankerName);
    await tankerInputs.nth(2).fill('12000');
    await tankerInputs.nth(3).fill('UI Smoke Owner');
    await tankerInputs.nth(4).fill('C1');
    await tankerInputs.nth(5).fill('Compartment 1');
    await tankerInputs.nth(6).fill('12000');
    await page.getByText('Save', { exact: true }).click();

    await expect
      .poll(async () => {
        const response = await request.get(
          'http://127.0.0.1:8012/tankers/?station_id=3&limit=100',
          {
            headers: {
              Authorization: `Bearer ${authToken}`,
            },
          },
        );
        if (!response.ok()) {
          return false;
        }
        const tankers = await response.json();
        return tankers.some((tanker) => tanker.name === tankerName);
      }, {
        timeout: 60000,
      })
      .toBe(true);
  });
});
