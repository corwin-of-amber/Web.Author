import { EventEmitter } from 'events';
import { minimalSetup } from 'codemirror';
import { Extension, StateField } from '@codemirror/state';
import { lineNumbers, keymap, highlightActiveLine,
         highlightActiveLineGutter } from '@codemirror/view';
import { indentWithTab } from '@codemirror/commands';


const changeGeneration = StateField.define<number>({
    create(state) { return 0; },
    update(value, tr) { return value + 1; }
});

const events = StateField.define<EventEmitter>({
    create(state) { return new EventEmitter; },
    update(value, tr) { return value; }
});

const setup: Extension[] = [
    keymap.of([{key: "Mod-Enter", run: () => true}]),
    minimalSetup, keymap.of([indentWithTab]),
    lineNumbers(), highlightActiveLine(), highlightActiveLineGutter(),
    changeGeneration, events
];


export { setup, changeGeneration, events }