import { keyName } from 'w3c-keyname';


class KeyMap {
    mapping: Map<string, KeyMap.Callback>

    constructor(mapping: Map<string, KeyMap.Callback> | {[key: string]: KeyMap.Callback}) {
        if (mapping instanceof Map)
            this.mapping = mapping;
        else {
            this.mapping = new Map;
            for (let [k, v] of Object.entries(mapping))
                this.mapping.set(k, v);
        }
    }

    invoke(ev: KeyboardEvent) {
        for (let mod of [{}, {[KeyMap.Mod]: "Mod-"}] as KeyMap.ModSet[]) {
            let cb = this.mapping.get(KeyMap.keyDescriptor(ev, mod));
            if (cb && cb(ev) !== false) { ev.stopPropagation(); break; }
        }
    }

    attach(el: Element) {
        el.addEventListener('keydown', (ev: KeyboardEvent) => this.invoke(ev));
    }
}

namespace KeyMap {

    export type Callback = (ev: KeyboardEvent) => boolean
    export type ModSet = {[modKey: string]: string}

    export function keyDescriptor(event: KeyboardEvent, mod?: ModSet) {
        var base = keyName(event);
        if (base.length === 1) base = base.toUpperCase();
        return modifiers(base, event, mod);
    }

    /* from `@codemirror/view` */
    export function modifiers(name: string, event: KeyboardEvent, mod: ModSet = {}) {
        let of = (k: string) => mod[k] ?? `${k}-`;
        if (event.altKey) name = of("Alt") + name;
        if (event.ctrlKey) name = of("Ctrl") + name;
        if (event.metaKey) name = of("Meta") + name;
        if (event.shiftKey) name = of("Shift") + name;
        return name
    }

    export const Mod = /Mac/.test(navigator.userAgent) ? 'Meta' : 'Ctrl';
}


export { KeyMap }