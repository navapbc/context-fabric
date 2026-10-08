/* Static reader: untrusted YAML is always rendered with text nodes. */
(() => {
  'use strict';
  const MAX_FILE_BYTES = 5 * 1024 * 1024;
  const MAX_EXPANDED_CHARS = 5 * 1024 * 1024;
  const byId = id => document.getElementById(id);
  const state = { view: null, raw: '', name: '', selected: '', findings: null, downloadUrl: null, viewRequest: 0 };
  const el = (tag, text, className) => {
    const node = document.createElement(tag);
    if (text !== undefined) node.textContent = String(text);
    if (className) node.className = className;
    return node;
  };
  const label = key => String(key).replaceAll('_', ' ').replace(/\b\w/g, c => c.toUpperCase());
  const isRecord = value => value !== null && typeof value === 'object' && !Array.isArray(value);
  const safeUrl = value => {
    if (typeof value !== 'string') return null;
    try {
      // A document location is url:https://...; the prefix is grammar, not the scheme.
      const url = new URL(value.startsWith('url:') ? value.slice(4) : value);
      return ['http:', 'https:'].includes(url.protocol) ? url.href : null;
    } catch { return null; }
  };
  const clear = node => node.replaceChildren();
  const message = (text, error = false) => {
    byId('message').textContent = text;
    byId('message').classList.toggle('error', error);
  };

  // Maps whose keys are data, such as variable names, never field names to prettify.
  const DATA_KEYED = new Set(['env', 'renamed_env', 'auth_methods']);

  function valueNode(value, verbatimKeys = false) {
    if (value === null || value === undefined) return el('span', 'Not specified', 'empty');
    if (Array.isArray(value)) {
      if (!value.length) return el('span', 'None recorded', 'empty');
      const list = el('ul');
      for (const item of value) { const row = el('li'); row.append(valueNode(item)); list.append(row); }
      return list;
    }
    if (isRecord(value)) {
      if (!Object.keys(value).length) return el('span', 'None recorded', 'empty');
      const list = el('dl', undefined, 'fields');
      for (const [key, item] of Object.entries(value)) {
        list.append(el('dt', verbatimKeys ? key : label(key)));
        const row = el('dd'); row.append(valueNode(item, DATA_KEYED.has(key))); list.append(row);
      }
      return list;
    }
    const url = safeUrl(value);
    if (url) {
      const link = el('a', value);
      link.href = url;
      link.target = '_blank';
      link.rel = 'noopener noreferrer';
      return link;
    }
    return el('span', String(value));
  }

  function field(parent, name, value) {
    const list = el('dl', undefined, 'fields');
    list.append(el('dt', name));
    const item = el('dd'); item.append(valueNode(value)); list.append(item);
    parent.append(list);
  }

  function validate(view) {
    if (!isRecord(view)) throw Error('The view must be a YAML mapping.');
    if (view.view_contract !== 2) throw Error('Unsupported view contract. This reader supports view contract 2.');
    if (!['org', 'bounded-context'].includes(view.kind)) throw Error('Unsupported view kind.');
    if (typeof view.id !== 'string' || !view.id || !Number.isInteger(view.release) || !Array.isArray(view.systems))
      throw Error('The view is missing its ID, release, or systems list.');
    if (view.kind === 'org' && !isRecord(view.organization)) throw Error('The Org view is missing organization details.');
    if (view.kind === 'bounded-context' && !isRecord(view.identity)) throw Error('The Bounded Context view is missing identity details.');
    if (!view.systems.every(system => isRecord(system) && typeof system.id === 'string' && Array.isArray(system.interfaces) && system.interfaces.every(isRecord)))
      throw Error('A system is malformed or missing interfaces.');
    let nodes = 0, expandedChars = 0;
    const ancestors = new Set();
    const visit = (value, depth) => {
      if (++nodes > 100000 || depth > 50) throw Error('The view is too large or deeply nested.');
      if (typeof value === 'string' && (expandedChars += value.length) > MAX_EXPANDED_CHARS)
        throw Error('The view is too large after YAML expansion.');
      if (value === null || typeof value !== 'object') return;
      if (ancestors.has(value)) throw Error('The view contains a circular YAML reference.');
      ancestors.add(value);
      for (const child of Object.values(value)) visit(child, depth + 1);
      ancestors.delete(value);
    };
    visit(view, 0);
    return view;
  }

  function renderRetention() {
    const box = byId('retention'); clear(box);
    const retained = Array.isArray(state.findings) && state.findings.length > 0;
    box.classList.toggle('retained', retained);
    box.append(el('h3', retained ? 'Retained view: publication blocked' : 'Currentness not verified'));
    if (retained) {
      box.append(el('p', 'These findings explain why the previous generated view was kept. Review the source before relying on currentness.'));
      box.append(valueNode(state.findings));
    } else {
      box.append(el('p', state.findings ? 'The selected sidecar has no findings; currentness still requires a generation check.' : 'No retention sidecar was loaded. Its absence does not establish that this copy is current.'));
    }
  }

  function interfaceCard(item) {
    const node = el('section', undefined, 'interface');
    node.append(el('h4', `${item.id || 'Unnamed interface'} · ${item.type || 'Type unknown'}`));
    field(node, 'Status', item.status);
    field(node, 'Locators', item.locators);
    field(node, 'Network', item.network);
    field(node, 'Authentication', item.auth);
    const extra = { ...item };
    for (const key of ['id', 'type', 'status', 'locators', 'network', 'auth']) delete extra[key];
    if (Object.keys(extra).length) {
      const more = el('details'); more.append(el('summary', 'More interface detail'), valueNode(extra)); node.append(more);
    }
    return node;
  }

  function systemCard(system) {
    const node = el('article', undefined, 'card');
    node.id = `system-${state.view.systems.indexOf(system)}`;
    const status = el('span', system.status || 'Status unknown', `badge ${system.status || ''}`); node.append(status);
    node.append(el('h3', system.name || system.id));
    const core = { id: system.id, ref: system.ref, source: system.source, declared: system.declared, kind: system.kind, maintainer: system.maintainer, scope: system.scope };
    for (const [key, value] of Object.entries(core)) if (value !== undefined) field(node, label(key), value);
    node.append(el('h4', 'Interfaces'));
    if (!system.interfaces.length) node.append(el('p', 'No interface recorded.', 'empty'));
    for (const item of system.interfaces) node.append(interfaceCard(item));
    const extra = { ...system };
    for (const key of [...Object.keys(core), 'name', 'status', 'interfaces']) delete extra[key];
    if (Object.keys(extra).length) {
      const more = el('details'); more.append(el('summary', 'More system detail'), valueNode(extra)); node.append(more);
    }
    return node;
  }

  function renderSystems() {
    const list = byId('system-list'), detail = byId('detail'); clear(list); clear(detail);
    const query = byId('search').value.trim().toLowerCase();
    const rows = state.view.systems.filter(system => JSON.stringify(system).toLowerCase().includes(query));
    byId('result-count').textContent = `${rows.length} of ${state.view.systems.length} systems`;
    if (!rows.length) { detail.append(el('p', 'No systems match. Clear the search or try another term.', 'card empty')); return; }
    if (!rows.some(item => item.id === state.selected)) state.selected = rows[0].id;
    for (const system of rows) {
      const button = el('button'); button.type = 'button';
      button.append(el('strong', system.name || system.id), el('small', `${system.kind || 'Kind unknown'} · ${system.status || 'Status unknown'} · ${system.source || 'Source unknown'}`));
      button.setAttribute('aria-current', String(system.id === state.selected));
      button.addEventListener('click', () => { state.selected = system.id; renderSystems(); byId('detail').querySelector('h3')?.focus(); });
      list.append(button);
    }
    const selected = rows.find(item => item.id === state.selected);
    const card = systemCard(selected); card.querySelector('h3').tabIndex = -1; detail.append(card);
  }

  function renderOther() {
    const target = byId('other-sections'); clear(target);
    const omitted = new Set(['view_contract', 'kind', 'id', 'release', 'organization', 'identity', 'systems', 'index']);
    const view = state.view;
    for (const [key, value] of Object.entries(view)) {
      if (omitted.has(key)) continue;
      const section = el('details', undefined, 'card context-section');
      section.append(el('summary', label(key)), valueNode(value, DATA_KEYED.has(key))); target.append(section);
    }
    const overview = view.kind === 'org' ? view.organization : view.identity;
    const section = el('details', undefined, 'card context-section');
    section.append(el('summary', view.kind === 'org' ? 'Organization' : 'Identity'), valueNode(overview));
    target.prepend(section);
  }

  function render() {
    byId('reader').hidden = false;
    byId('view-type').textContent = `${state.view.kind === 'org' ? 'Organization' : 'Bounded Context'} · release ${state.view.release} · contract ${state.view.view_contract}`;
    byId('view-title').textContent = (state.view.kind === 'org' ? state.view.organization.name : state.view.identity.name) || state.view.id;
    byId('view-summary').textContent = state.view.kind === 'bounded-context' ? state.view.identity.purpose || '' : `Generated view ${state.view.id}`;
    renderRetention(); renderSystems(); renderOther();
  }

  function loadView(raw, name) {
    const parsed = validate(jsyaml.load(raw, { schema: jsyaml.JSON_SCHEMA }));
    state.view = parsed; state.raw = raw; state.name = name; state.selected = parsed.systems[0]?.id || '';
    state.findings = null;
    if (state.downloadUrl) URL.revokeObjectURL(state.downloadUrl);
    state.downloadUrl = URL.createObjectURL(new Blob([raw], { type: 'text/yaml' }));
    byId('download').href = state.downloadUrl;
    byId('search').value = '';
    render(); message(`Opened ${name}.`);
  }

  function loadSidecar(raw, name) {
    if (!state.view) throw Error('Choose a view before its retention sidecar.');
    const lines = raw.split(/\r?\n/).filter(line => line.trim());
    const findings = lines.map((line, index) => {
      let value;
      try { value = JSON.parse(line); } catch { throw Error(`Invalid JSON on sidecar line ${index + 1}.`); }
      if (!isRecord(value) || typeof value.code !== 'string') throw Error(`Invalid finding on sidecar line ${index + 1}.`);
      return value;
    });
    state.findings = findings; renderRetention(); message(`Opened ${name}.`);
  }

  async function readResponse(response) {
    if (!response.body) {
      const raw = await response.text();
      if (new Blob([raw]).size > MAX_FILE_BYTES) throw Error('Choose a file smaller than 5 MB.');
      return raw;
    }
    const reader = response.body.getReader();
    const chunks = [];
    let size = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_FILE_BYTES) {
        await reader.cancel();
        throw Error('Choose a file smaller than 5 MB.');
      }
      chunks.push(value);
    }
    return new Blob(chunks).text();
  }

  async function openFile(file) {
    const sidecar = /\.jsonl$/i.test(file.name);
    const request = sidecar ? state.viewRequest : ++state.viewRequest;
    try {
      if (file.size > MAX_FILE_BYTES) throw Error('Choose a file smaller than 5 MB.');
      const raw = await file.text();
      if (request !== state.viewRequest) return;
      if (sidecar) loadSidecar(raw, file.name);
      else loadView(raw, file.name);
    } catch (error) {
      if (request !== state.viewRequest) return;
      if (!sidecar) { state.view = null; byId('reader').hidden = true; }
      else { state.findings = null; if (state.view) renderRetention(); }
      message(error.message || 'Could not open this file.', true);
    }
  }

  byId('view-file').addEventListener('change', event => { if (event.target.files[0]) openFile(event.target.files[0]); });
  byId('retained-file').addEventListener('change', event => { if (event.target.files[0]) openFile(event.target.files[0]); });
  byId('search').addEventListener('input', () => { if (state.view) renderSystems(); });
  let printOpenStates = [];
  window.addEventListener('beforeprint', () => {
    if (!state.view) return;
    const detail = byId('detail'); clear(detail);
    for (const system of state.view.systems) detail.append(systemCard(system));
    for (const section of detail.querySelectorAll('details')) section.open = true;
    printOpenStates = [...byId('other-sections').querySelectorAll('details')].map(section => section.open);
    for (const section of byId('other-sections').querySelectorAll('details')) section.open = true;
  });
  window.addEventListener('afterprint', () => {
    if (!state.view) return;
    renderSystems();
    [...byId('other-sections').querySelectorAll('details')].forEach((section, index) => { section.open = printOpenStates[index] || false; });
  });
  const drop = byId('drop-zone');
  drop.addEventListener('dragover', event => { event.preventDefault(); drop.classList.add('dragging'); });
  drop.addEventListener('dragleave', () => drop.classList.remove('dragging'));
  drop.addEventListener('drop', async event => {
    event.preventDefault(); drop.classList.remove('dragging');
    const files = [...event.dataTransfer.files];
    for (const file of files.filter(item => !/\.jsonl$/i.test(item.name))) await openFile(file);
    for (const file of files.filter(item => /\.jsonl$/i.test(item.name))) await openFile(file);
  });

  const requested = new URL(location.href).searchParams.get('view');
  if (requested) {
    const request = ++state.viewRequest;
    try {
      if (location.protocol === 'file:') throw Error('Choose a local YAML file when opening the reader from disk.');
      const url = new URL(requested, location.href);
      if (url.origin !== location.origin || !url.pathname.endsWith('/view.yaml')) throw Error('Hosted view must be a same-origin view.yaml.');
      fetch(url.href, { cache: 'no-store' }).then(async response => {
        if (!response.ok) throw Error(`Hosted view could not be loaded (${response.status}).`);
        const raw = await readResponse(response);
        if (request !== state.viewRequest) return;
        loadView(raw, url.pathname);
        const sidecar = new URL('RETAINED.jsonl', url);
        let retained;
        try { retained = await fetch(sidecar.href, { cache: 'no-store' }); }
        catch { return; }
        if (retained.ok) {
          const rawSidecar = await readResponse(retained);
          if (request === state.viewRequest) loadSidecar(rawSidecar, sidecar.pathname);
        }
      }).catch(error => {
        if (request === state.viewRequest) message(error.message || 'Could not open hosted view.', true);
      });
    } catch (error) { message(error.message, true); }
  }
})();
