// Run with: PLAYWRIGHT_PATH=/path/to/playwright node reader/reader.test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');

const root = path.resolve(__dirname, '..');
const reader = path.join(__dirname, 'index.html');
const org = path.join(root, 'views/meridian-health-agency/view.yaml');
const bc = path.join(root, 'views/claims-intake-modernization/view.yaml');

(async () => {
  const browser = await chromium.launch({ channel: process.env.PLAYWRIGHT_CHANNEL || 'chrome', headless: true });
  try {
  const page = await browser.newPage();
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  let requests = 0;
  page.on('request', request => { if (/^https?:/.test(request.url())) requests++; });
  await page.goto(`file://${reader}`);
  await page.locator('#view-file').setInputFiles(bc);
  await page.getByRole('heading', { name: 'Claims Intake Modernization' }).waitFor();
  assert.match(await page.locator('#retention').innerText(), /Currentness not verified/);
  assert.match(await page.locator('#other-sections').innerText(), /Unreferenced Systems|Other Systems/i);
  assert.match(await page.locator('#other-sections').innerText(), /Source Selection/);
  await page.locator('#other-sections summary').filter({ hasText: 'Repositories' }).click();
  assert.match(await page.locator('#other-sections').innerText(), /partial/);
  assert.match(await page.locator('#other-sections').innerText(), /src\/intake\//);
  // A location is url:https://..., and the url: prefix is the grammar, not the scheme.
  assert.equal(await page.locator('#other-sections a[href="https://code.meridian.invalid/meridian-claims-operations/intake-service"]').count(), 1,
    'a url: repository location is a link to its https destination');
  await page.locator('#other-sections summary').filter({ hasText: 'Anchors' }).click();
  assert.equal(await page.locator('#other-sections a[href="https://wiki.meridian.invalid/spaces/intake/runbook"]').count(), 1,
    'a url: anchor location is a link to its https destination');
  assert.match(await page.locator('#detail').innerText(), /MERIDIAN_WIKI_TOKEN/, 'an environment variable name is shown exactly as written');
  await page.locator('#other-sections summary').filter({ hasText: 'Unreferenced Systems' }).click();
  assert.match(await page.locator('#other-sections').innerText(), /meridian-health-agency#/);
  assert.match(await page.locator('#detail').innerText(), /meridian-health-agency#program-wiki/);
  await page.locator('#search').fill('issue-tracker');
  assert.match(await page.locator('#detail').innerText(), /Issue Tracker/);
  await page.locator('#system-list button').first().focus();
  await page.keyboard.press('Enter');
  assert.equal(await page.locator('#system-list button[aria-current="true"]').count(), 1);
  assert.equal(requests, 0, 'local file mode must not make network requests');

  await page.locator('#retained-file').setInputFiles({ name: 'RETAINED.jsonl', mimeType: 'application/json', buffer: Buffer.from('{"code":"UPSTREAM_INVALID","message":"Previous view kept"}\n') });
  await page.getByRole('heading', { name: 'Retained view: publication blocked' }).waitFor();
  assert.match(await page.locator('#retention').innerText(), /Retained view: publication blocked/);
  assert.match(await page.locator('#retention').innerText(), /UPSTREAM_INVALID/);

  await page.locator('#view-file').setInputFiles(org);
  await page.getByRole('heading', { name: 'Meridian Health Agency' }).waitFor();
  assert.match(await page.locator('#detail').innerText(), /Interfaces/);
  await page.locator('#other-sections summary').filter({ hasText: 'Auth Methods' }).click();
  assert.match(await page.locator('#other-sections').innerText(), /A tool already signed in on this machine/);
  assert.match(await page.locator('#other-sections').innerText(), /host_tool/, 'an auth method ID is shown exactly as written');
  assert.equal(await page.locator('#download').getAttribute('download'), 'view.yaml');
  await page.evaluate(() => window.dispatchEvent(new Event('beforeprint')));
  assert.equal(await page.locator('#detail .card').count(), 9, 'print includes every system');
  await page.evaluate(() => window.dispatchEvent(new Event('afterprint')));

  const malicious = [
    'view_contract: 2', 'kind: org', 'id: test', 'release: 1',
    'organization: {name: Test}', 'systems:',
    '  - id: test-system', '    name: "<img src=x onerror=alert(1)>"', '    location: "url:javascript:alert(2)"',
    '    interfaces:', '      - id: web', '        type: web',
    '        locators:', '          - role: endpoint', '            url: "javascript:alert(1)"',
  ].join('\n');
  await page.locator('#view-file').setInputFiles({ name: 'view.yaml', mimeType: 'text/yaml', buffer: Buffer.from(malicious) });
  await page.getByRole('heading', { name: 'Test' }).waitFor();
  assert.match(await page.locator('#detail').innerText(), /<img src=x onerror=alert\(1\)>/);
  assert.equal(await page.locator('#detail img').count(), 0);
  assert.equal(await page.locator('#detail a[href^="javascript:"]').count(), 0);
  assert.match(await page.locator('#detail').innerText(), /javascript:alert\(1\)/);
  await page.locator('#detail summary').filter({ hasText: 'More system detail' }).click();
  assert.match(await page.locator('#detail').innerText(), /url:javascript:alert\(2\)/);
  assert.equal(await page.locator('#detail a').count(), 0, 'a url: location with an unsafe scheme is not a link');

  // View contract 3 adds a one-line purpose on systems and interfaces, and api.spec_format.
  const view3 = [
    'view_contract: 3', 'kind: org', 'id: purpose-test', 'release: 1',
    'organization: {name: Purpose Test}', 'systems:',
    '  - id: tracker', '    name: Purpose Tracker', '    kind: web-app', '    status: active', '    source: purpose-test@1',
    '    purpose: Tracks work items for program teams',
    '    interfaces:',
    '      - id: rest', '        type: rest', '        purpose: Read and update work items',
    '        api: {schema_url: "https://tracker.invalid/openapi.json", spec_format: openapi}',
    '      - id: web', '        type: web',
    '  - id: quiet', '    name: Quiet System', '    kind: service', '    status: active', '    source: purpose-test@1', '    interfaces: []',
    '  - id: markup', '    name: Markup System', '    kind: service', '    status: active', '    source: purpose-test@1',
    '    purpose: "<b>bold</b><img src=x onerror=alert(3)>"', '    interfaces: []',
  ].join('\n');
  await page.locator('#view-file').setInputFiles({ name: 'view.yaml', mimeType: 'text/yaml', buffer: Buffer.from(view3) });
  await page.getByRole('heading', { name: 'Purpose Test' }).waitFor();
  assert.match(await page.locator('#view-type').innerText(), /contract 3/);
  assert.equal(await page.locator('#detail .card > h3 + .purpose').innerText(), 'Tracks work items for program teams',
    'the system purpose sits directly under the card heading');
  const interfaces = page.locator('#detail .interface');
  assert.equal(await interfaces.nth(0).locator('h4 + .purpose').innerText(), 'Read and update work items',
    'the interface purpose sits under its heading');
  assert.equal(await interfaces.nth(1).locator('h4 + .purpose').innerText(), 'Not specified',
    'a missing interface purpose shows the placeholder');
  assert.equal(await page.locator('#detail summary').filter({ hasText: 'More system detail' }).count(), 0,
    'purpose is not repeated in the system extras');
  await interfaces.nth(0).locator('summary').filter({ hasText: 'More interface detail' }).click();
  const restText = await interfaces.nth(0).innerText();
  assert.match(restText, /Spec Format\s+openapi/, 'spec_format is visible in interface detail');
  assert.match(restText, /Schema Url\s+https:\/\/tracker\.invalid\/openapi\.json/);
  assert.equal(restText.split('Read and update work items').length - 1, 1, 'interface purpose is shown once');
  const rows = page.locator('#system-list button');
  assert.equal(await rows.nth(0).locator('.purpose').innerText(), 'Tracks work items for program teams',
    'the system list shows the purpose on its own line');
  assert.equal(await rows.nth(1).locator('.purpose').count(), 0, 'a missing purpose adds no system-list line');
  assert.equal(await rows.nth(1).locator('small').count(), 1);
  await rows.nth(1).click();
  assert.equal(await page.locator('#detail .card > h3 + .purpose').innerText(), 'Not specified',
    'a missing system purpose shows the placeholder under the heading');
  await page.locator('#system-list button').nth(2).click();
  assert.equal(await page.locator('#detail .card > h3 + .purpose').innerText(), '<b>bold</b><img src=x onerror=alert(3)>');
  assert.equal(await page.locator('#detail b, #detail img, #system-list b, #system-list img').count(), 0,
    'purpose markup renders as text and creates no element');
  assert.equal(await page.locator('#system-list button').nth(2).locator('.purpose').innerText(), '<b>bold</b><img src=x onerror=alert(3)>');

  await page.locator('#view-file').setInputFiles({ name: 'broken.yaml', mimeType: 'text/yaml', buffer: Buffer.from('[broken') });
  await page.locator('#message').filter({ hasText: /unexpected end|bad indentation|missed comma|flow sequence/i }).waitFor();
  assert.match(await page.locator('#message').innerText(), /unexpected end|bad indentation|missed comma|flow sequence/i);
  await page.locator('#view-file').setInputFiles({ name: 'unsupported.yaml', mimeType: 'text/yaml', buffer: Buffer.from('view_contract: 4\nkind: org\n') });
  await page.getByText('Unsupported view contract. This reader supports view contracts 2 and 3.').waitFor();
  assert.match(await page.locator('#message').innerText(), /Unsupported view contract/);
  assert.equal(await page.locator('#reader').isVisible(), false);
  await page.locator('#view-file').setInputFiles({ name: 'circular.yaml', mimeType: 'text/yaml', buffer: Buffer.from('view_contract: 2\nkind: org\nid: test\nrelease: 1\norganization: &anchor {name: Test, loop: *anchor}\nsystems: []\n') });
  await page.getByText('The view contains a circular YAML reference.').waitFor();
  assert.match(await page.locator('#message').innerText(), /circular YAML reference/);
  const aliasBomb = ['view_contract: 2', 'kind: org', 'id: test', 'release: 1', 'organization: {name: Test}', 'systems: []', `large: &text "${'x'.repeat(256 * 1024)}"`, 'repeated:', ...Array(32).fill('  - *text')].join('\n');
  await page.locator('#view-file').setInputFiles({ name: 'expanded.yaml', mimeType: 'text/yaml', buffer: Buffer.from(aliasBomb) });
  await page.getByText('The view is too large after YAML expansion.').waitFor();
  assert.match(await page.locator('#message').innerText(), /too large after YAML expansion/);
  assert.deepEqual(errors, []);

  const server = http.createServer((request, response) => {
    const filename = request.url.split('?')[0];
    if (filename === '/oversized/view.yaml') { response.end('x'.repeat(5 * 1024 * 1024 + 1)); return; }
    if (filename === '/race/RETAINED.jsonl') {
      setTimeout(() => response.end('{"code":"UPSTREAM_INVALID","message":"Old hosted view"}\n'), 250);
      return;
    }
    if (filename === '/bad-sidecar/RETAINED.jsonl') { response.end('{bad json\n'); return; }
    if (filename === '/views/meridian-health-agency/RETAINED.jsonl') {
      response.end('{"code":"UPSTREAM_INVALID","message":"Previous view kept"}\n'); return;
    }
    const files = {
      '/reader/index.html': reader,
      '/reader/reader.css': path.join(__dirname, 'reader.css'),
      '/reader/reader.js': path.join(__dirname, 'reader.js'),
      '/reader/vendor/js-yaml.min.js': path.join(__dirname, 'vendor/js-yaml.min.js'),
      '/views/meridian-health-agency/view.yaml': org,
      '/race/view.yaml': org,
      '/bad-sidecar/view.yaml': org,
    };
    if (!files[filename]) { response.writeHead(404); response.end(); return; }
    response.setHeader('Content-Type', filename.endsWith('.js') ? 'text/javascript' : filename.endsWith('.css') ? 'text/css' : filename.endsWith('.html') ? 'text/html' : 'text/yaml');
    response.end(fs.readFileSync(files[filename]));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    const port = server.address().port;
    await page.goto(`http://127.0.0.1:${port}/reader/index.html?view=/views/meridian-health-agency/view.yaml`);
    await page.getByRole('heading', { name: 'Meridian Health Agency' }).waitFor();
    await page.getByRole('heading', { name: 'Retained view: publication blocked' }).waitFor();
    assert.match(await page.locator('#retention').innerText(), /UPSTREAM_INVALID/);

    await page.goto(`http://127.0.0.1:${port}/reader/index.html?view=/bad-sidecar/view.yaml`);
    await page.getByRole('heading', { name: 'Meridian Health Agency' }).waitFor();
    await page.getByText('Invalid JSON on sidecar line 1.').waitFor();
    assert.match(await page.locator('#retention').innerText(), /Currentness not verified/);

    const raceResponse = page.waitForResponse(response => response.url().endsWith('/race/RETAINED.jsonl'));
    await page.goto(`http://127.0.0.1:${port}/reader/index.html?view=/race/view.yaml`);
    await page.getByRole('heading', { name: 'Meridian Health Agency' }).waitFor();
    await page.locator('#view-file').setInputFiles(bc);
    await page.getByRole('heading', { name: 'Claims Intake Modernization' }).waitFor();
    await raceResponse;
    await page.waitForTimeout(30);
    assert.match(await page.locator('#retention').innerText(), /Currentness not verified/);

    await page.goto(`http://127.0.0.1:${port}/reader/index.html?view=/oversized/view.yaml`);
    await page.getByText('Choose a file smaller than 5 MB.').waitFor();
  } finally { server.close(); }
  console.log('reader browser checks passed');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
