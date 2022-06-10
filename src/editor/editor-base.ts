import { minimalSetup } from 'codemirror';
import { lineNumbers, highlightActiveLineGutter, keymap, highlightActiveLine } from '@codemirror/view';


const setup = [
    minimalSetup,
    lineNumbers(), highlightActiveLine()
];


export { setup }