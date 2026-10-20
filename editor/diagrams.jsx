import { Component } from 'react';
import { createRoot } from 'react-dom/client';
import { flushSync } from 'react-dom';
import { EMPTY_DOCUMENT, parseDiagramDocument } from '@scribblesvg/core';
import { DiagramCanvas } from '@scribblesvg/react-utils/editor';
import { DiagramRenderer } from '@scribblesvg/react-utils/renderer';
import '@scribblesvg/react-utils/editor.css';

// A diagram stays a plain Markdown point, including in backups and Copy.
// Only a complete, dedicated fence is treated as a diagram; prose around a
// fence remains editable Markdown. Invalid documents remain editable as text.
function read(source) {
  const match = /^```scribblesvg\r?\n([\s\S]*?)\r?\n```$/.exec(source.trim());
  if (!match) return null;
  try { return { document: parseDiagramDocument(JSON.parse(match[1])) }; }
  catch (error) { return { error: `Cannot render this diagram: ${error.message}` }; }
}
function write(document) {
  return '```scribblesvg\n' + JSON.stringify(parseDiagramDocument(document)) + '\n```';
}

class DiagramBoundary extends Component {
  state = { failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  render() {
    return this.state.failed
      ? <p role="alert">This diagram could not be displayed. Its saved source is unchanged.</p>
      : this.props.children;
  }
}

function preview(element, initialSource, onEdit, onFocus) {
  const root = createRoot(element);
  let source = initialSource;
  function render() {
    const result = read(source);
    root.render(<DiagramBoundary key={source}>
      <button className="diagram-preview" aria-label="Edit diagram" onClick={onEdit} onFocus={onFocus}>
        <DiagramRenderer document={result.document} aria-label="Diagram"
          colors={{ stroke: 'var(--foreground)', text: 'var(--foreground)' }} />
        <span>{result.document.elements.length ? 'Edit diagram' : 'Empty diagram · click to draw'}</span>
      </button>
    </DiagramBoundary>);
  }
  render();
  return {
    getValue: () => source,
    setValue(value) { source = value; render(); },
    focus() { element.querySelector('button')?.focus(); },
    destroy() { root.unmount(); },
  };
}

function edit(initialSource, onChange, onClose) {
  const dialog = document.createElement('dialog');
  dialog.className = 'diagram-dialog';
  dialog.setAttribute('aria-label', 'Edit diagram');
  const header = document.createElement('header');
  const label = document.createElement('span');
  label.textContent = 'ScribbleSVG · autosaved';
  const done = document.createElement('button');
  done.textContent = 'Done';
  done.title = 'Return to notes (Ctrl+Enter)';
  const canvas = document.createElement('div');
  canvas.className = 'diagram-canvas';
  header.append(label, done);
  dialog.append(header, canvas);
  document.body.append(dialog);
  const root = createRoot(canvas);
  let closed = false;
  let previous = write(read(initialSource).document);
  function close() {
    if (closed) return;
    // Commit a label still being typed before unmounting the canvas.
    flushSync(() => document.activeElement?.blur());
    closed = true;
    root.unmount();
    dialog.close();
    dialog.remove();
    onClose();
  }
  done.addEventListener('click', close);
  // Escape belongs to ScribbleSVG (cancel drawing, selection, or label edit).
  dialog.addEventListener('cancel', event => event.preventDefault());
  dialog.showModal();
  root.render(<DiagramBoundary>
    <DiagramCanvas initialDocument={read(initialSource).document} onChange={document => {
      const source = write(document);
      if (source !== previous && !closed) { previous = source; onChange(source); }
    }} />
  </DiagramBoundary>);
  return { close };
}

window.scratchpadDiagrams = { read, write, preview, edit, empty: write(EMPTY_DOCUMENT) };
