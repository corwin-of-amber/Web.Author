import { EventEmitter } from 'events';
import { minimalSetup } from 'codemirror';
import { Extension, StateField, EditorSelection,
         SelectionRange } from '@codemirror/state';
import { EditorView, lineNumbers, keymap, highlightActiveLine,
         highlightActiveLineGutter, WidgetType, ViewPlugin, DecorationSet, Decoration } from '@codemirror/view';
import { indentWithTab } from '@codemirror/commands';


const changeGeneration = StateField.define<number>({
    create(state) { return 0; },
    update(value, tr) { return value + 1; }
});

const events = StateField.define<EventEmitter>({
    create(state) { return new EventEmitter; },
    update(value, tr) {
        if (tr.newSelection !== tr.startState.selection)
            defer(() => value.emit('cursorActivity', tr));
        return value;
    }
});

const setup: Extension[] = [
    keymap.of([{key: "Mod-Enter", run: () => true}]),
    minimalSetup, keymap.of([indentWithTab]),
    lineNumbers(), highlightActiveLine(), highlightActiveLineGutter(),
    changeGeneration, events
];


class EditorViewWithBenefits extends EditorView {

    setCursor(pos: number | LineCh) {
        if (typeof pos !== 'number') pos = this.posToOffset(pos)
        this.dispatch({
            selection: EditorSelection.create([EditorSelection.cursor(pos)]),
            effects: EditorView.scrollIntoView(pos, {y: 'center'})
        });
    }

    getCursorOffset(w: 'head' | 'from' | 'to' = 'head') {
        return this.state.selection.asSingle().ranges[0][w];
    }

    getCursor(w?: 'head' | 'from' | 'to') {
        return this.offsetToPos(this.getCursorOffset(w));
    }

    posToOffset(pos: LineCh): number {
        return this.state.doc.line(pos.line).from + pos.ch;
    }

    offsetToPos(offset: number) {
        let line = this.state.doc.lineAt(offset);
        return {line: line.number, ch: offset - line.from};
    }

    scrollTo(scroll: {top: number, left: number}) {
        let doc = this.state.doc,
            go = () => doc == this.state.doc && (this.scrollDOM.scrollTop = scroll.top);
        // and again once the DOM has settled
        go!; if (scroll.top !== 0) requestAnimationFrame(go);
    }

    getScroll() {
        let s = this.scrollDOM;
        return {top: s.scrollTop, left: s.scrollLeft};
    }
}


type LineCh = {line: number, ch: number};


/** A crutch because LiveScript code cannot extend ES6 classes :/ */
function createWidgetPlugin(factory: () => HTMLElement) {
    class WidgetWrapper extends WidgetType {
        toDOM(view: EditorView): HTMLElement { return factory(); }
    }

    return ViewPlugin.fromClass(class {
        decorations: DecorationSet
        constructor(view: EditorView) {
            this.decorations = Decoration.set(Decoration.widget({
                widget: new WidgetWrapper,
                side: 1
            }).range(view.state.doc.length));
        }
    }, {decorations: v => v.decorations});
}


function defer<T>(op: () => T) { Promise.resolve().then(op); }


export { setup, changeGeneration, events, EditorViewWithBenefits, LineCh,
         createWidgetPlugin }