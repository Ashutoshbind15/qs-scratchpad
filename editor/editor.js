/* Vditor owns parsing, input rules, tables, selection, and undo. This file
 * connects its editors to the native note model; it does not parse Markdown. */
const host = document.querySelector('#points');
const status = document.querySelector('#status');
const cdn = new URL('../node_modules/vditor', location.href).href;
let bridge;
let state;
let documentId = -1;
let points = [];
let pending;
let applying = false;
let darkTheme = true;
let editId = 0;

function send(type, extra = {}) {
  bridge.receive(JSON.stringify({ type, documentId, ...extra }));
}

function flush() {
  for (const point of points) {
    if (!point.dirty || !point.ready) continue;
    point.dirty = false;
    const text = point.editor.getValue();
    if (text !== point.source) {
      point.source = text;
      point.editId = ++editId;
      send('input', { id: point.id, text, editId: point.editId });
    }
  }
}

function createPoint(source, index, id) {
  const element = document.createElement('section');
  element.className = 'point';
  element.dataset.point = index;
  element.setAttribute('aria-label', `Point ${index + 1}`);
  const controls = document.createElement('div');
  controls.className = 'controls';
  for (const [text, label, action] of [['↑', 'Move point up', 'up'], ['↓', 'Move point down', 'down'], ['×', 'Remove point', 'remove']]) {
    const button = document.createElement('button');
    button.textContent = text;
    button.setAttribute('aria-label', label);
    button.dataset.action = action;
    button.addEventListener('click', () => {
      flush();
      send(action === 'remove' ? 'remove' : 'move', { id: point.id, offset: action === 'up' ? -1 : 1 });
    });
    controls.append(button);
  }
  const content = document.createElement('div');
  element.append(controls, content);
  host.append(element);
  const point = { id, source, index, element, documentId, editId: 0, ready: false, dirty: false, suppress: false };
  point.promise = new Promise(resolve => {
    point.editor = new Vditor(content, {
      cdn, mode: 'ir', lang: 'en_US', value: source, theme: darkTheme ? 'dark' : 'classic',
      cache: { enable: false }, toolbar: [], minHeight: 64, undoDelay: 250,
      resize: { enable: false }, counter: { enable: false },
      preview: { delay: 0, hljs: { enable: true, style: darkTheme ? 'github-dark' : 'github' }, math: { engine: 'KaTeX' },
        theme: { current: darkTheme ? 'dark' : 'light', path: `${cdn}/dist/css/content-theme` },
        markdown: { sanitize: true } },
      input() {
        if (!point.ready || point.suppress || point.documentId !== documentId) return;
        point.dirty = true;
        flush();
      },
      focus() {
        if (!point.ready || point.documentId !== documentId) return;
        send('focus', { id: point.id });
      },
      after() { point.ready = true; resolve(point); }
    });
  });
  return point;
}

async function applyState(next) {
  state = next;
  const rgb = next.palette.background.replace('#', '').match(/../g).slice(0, 3).map(value => parseInt(value, 16));
  darkTheme = rgb[0] * .2126 + rgb[1] * .7152 + rgb[2] * .0722 < 128;
  document.documentElement.style.colorScheme = darkTheme ? 'dark' : 'light';
  for (const [key, value] of Object.entries(next.palette)) {
    const css = key.replace(/[A-Z]/g, letter => `-${letter.toLowerCase()}`);
    document.documentElement.style.setProperty(`--${css}`, key === 'fontSize' ? `${value}px` : value);
  }
  document.body.classList.toggle('no-controls', !next.showControls);
  if (documentId !== next.documentId) {
    for (const point of points) { point.ready = false; point.editor.destroy(); }
    host.replaceChildren();
    points = [];
    documentId = next.documentId;
    window.scrollTo(0, 0);
  }
  // Runtime point IDs preserve documents and undo across inserts and moves,
  // including when several points contain identical Markdown.
  const unused = new Set(points);
  const reordered = [];
  for (let index = 0; index < next.entries.length; index++) {
    const { id, text: source } = next.entries[index];
    let point = [...unused].find(item => item.id === id);
    if (point) {
      unused.delete(point);
      if (point.source !== source && next.lastEditId >= point.editId) {
        point.suppress = true;
        point.editor.setValue(source, true);
        point.source = source;
        point.dirty = false;
        point.suppress = false;
      }
    } else point = createPoint(source, index, id);
    point.index = index;
    point.element.dataset.point = index;
    point.element.setAttribute('aria-label', `Point ${index + 1}`);
    if (host.children[index] !== point.element) {
      if (host.moveBefore) host.moveBefore(point.element, host.children[index] || null);
      else host.insertBefore(point.element, host.children[index] || null);
    }
    reordered.push(point);
  }
  for (const point of unused) { point.ready = false; point.editor.destroy(); point.element.remove(); }
  points = reordered;
  await Promise.all(points.map(point => point.promise));
  for (const point of points) {
    const theme = darkTheme ? 'dark' : 'classic';
    if (point.theme !== theme) {
      point.editor.setTheme(theme, darkTheme ? 'dark' : 'light', darkTheme ? 'github-dark' : 'github', `${cdn}/dist/css/content-theme`);
      point.theme = theme;
    }
    point.element.querySelector('[data-action="up"]').disabled = point.index === 0;
    point.element.querySelector('[data-action="down"]').disabled = point.index === points.length - 1;
  }
  status.hidden = true;
  if (next.focus) focusPoint(next.currentPoint);
  if (next.end) window.scratchpad.focusEnd();
}

async function drain() {
  if (applying) return;
  applying = true;
  try {
    while (pending) {
      const next = pending;
      pending = null;
      await applyState(next);
    }
  } catch (error) {
    status.hidden = false;
    status.textContent = `Editor failed to load: ${error.message}`;
    console.error(error);
  } finally { applying = false; }
}

function focusPoint(index) {
  const point = points[index];
  if (!point?.ready) return;
  point.editor.focus();
  ensureCursorVisible();
}

function ensureCursorVisible() {
  const selection = window.getSelection();
  if (!selection.rangeCount) return;
  const rect = selection.getRangeAt(0).getBoundingClientRect();
  if (rect.bottom > innerHeight) window.scrollBy(0, rect.bottom - innerHeight + 16);
  else if (rect.top < 0) window.scrollBy(0, rect.top - 16);
}

function chord(event) {
  const modifiers = [event.ctrlKey && 'Ctrl', event.altKey && 'Alt', event.shiftKey && 'Shift'].filter(Boolean);
  const key = ({ Enter: 'Return', ArrowUp: 'Up', ArrowDown: 'Down', Escape: 'Escape' })[event.key] || (event.key.length === 1 ? event.key.toUpperCase() : event.key);
  return [...modifiers, key].join('+');
}

document.addEventListener('keydown', event => {
  const sequence = chord(event);
  const binding = state?.shortcuts.find(item => item.section !== 'Anywhere' && item.sequences.includes(sequence));
  if (!binding) return;
  event.preventDefault();
  event.stopImmediatePropagation();
  // Let Vditor finish its input transaction before exporting and switching.
  const owner = documentId;
  setTimeout(() => { flush(); send('action', { action: binding.action, documentId: owner }); }, 0);
}, true);
document.addEventListener('input', event => {
  const element = event.target.closest('.point');
  if (element && points[Number(element.dataset.point)]) {
    points[Number(element.dataset.point)].dirty = true;
    setTimeout(flush, 0);
  }
}, true);
document.addEventListener('click', event => {
  const link = event.target.closest('a[href]');
  if (!link) return;
  event.preventDefault();
  send('link', { url: link.href });
});
document.addEventListener('selectionchange', () => requestAnimationFrame(ensureCursorVisible));
document.querySelector('#add').addEventListener('click', () => { flush(); send('action', { action: 'addPoint' }); });

window.scratchpad = {
  focusPoint, ensureCursorVisible, flush,
  focusEnd() {
    focusPoint(state.currentPoint);
    const editable = points[state.currentPoint]?.element.querySelector('.vditor-ir [contenteditable="true"]');
    if (!editable) return;
    const range = document.createRange();
    range.selectNodeContents(editable);
    range.collapse(false);
    const selection = getSelection();
    selection.removeAllRanges(); selection.addRange(range);
    ensureCursorVisible();
  },
  get points() { return points; },
  get documentId() { return documentId; }
};
new QWebChannel(qt.webChannelTransport, channel => {
  bridge = channel.objects.scratchpad;
  bridge.stateChanged.connect(raw => { pending = JSON.parse(raw); drain(); });
  send('ready');
});
