import { openDB, IDBPDatabase } from 'idb';
import { Volume } from '../infra/volume';
// @ts-ignore
import { FileWatcher } from '../infra/fs-watch.ls';


class LocalDBSync {
    name: string
    db: IDBPDatabase

    _ready: Promise<void>
    _queue: {filename: string, content: Uint8Array | string}[] = []
    _watch = new FileWatcher

    constructor(name: string) {
        this.name = name;
        this._ready = this.open();

        this._watch.on('change', ({origin, filename}) => {
            this.push({volume: origin.fs, filename});
        });
    }

    async open() {
        this.db = await this._open();
    }

    _open() {
        return openDB(this.name, 1, {
            upgrade(db) {
                db.createObjectStore('files');
            },
        });
    }

    async attach(volume: Volume) {
        /** @todo only root '/' is supported */
        await this.pullAll(volume);
        this.watch(volume);
    }

    watch(volume: Volume, root: string = "/") {
        this._watch.add(root, {fs: volume, recursive: true});
    }

    unwatch() {
        this._watch.clear();
    }

    async push({volume, filename}: Volume.Location) {
        await this._ready;
        var content = this._loadV({volume, filename});
        return content ? this._store(filename, content)
                       : this._delete(filename);
    }

    async pull({volume, filename}: Volume.Location) {
        await this._ready;
        var content = await this._load(filename);
        if (content) this._storeV({volume, filename}, content);
    }

    async pullAll(into: Volume) {
        await this._ready;
        var t = this.db.transaction('files'),
            c = await t.store.openCursor();
        while (c) {
            if (typeof c.key === 'string')
                this._storeV({volume: into, filename: c.key}, c.value);
            c = await c.continue();
        }
    }

    _store(filename: string, content: Uint8Array | string) {
        return this.db.put('files', content, filename);
    }

    _load(filename: string): Promise<string | Uint8Array> {
        return this.db.get('files', filename);
    }

    _delete(filename: string) {
        return this.db.delete('files', filename);
    }

    _storeV({volume, filename}: Volume.Location, content: Uint8Array | string) {
        try {
            volume.mkdirSync(volume.path.dirname(filename), {recursive: true});
            volume.writeFileSync(filename, content);
            return true;
        }
        catch (e) { console.warn('[LocalDBSync] cannot write', filename, `\n[${e}]`); return false; }    
    }

    _loadV({volume, filename}: Volume.Location) {
        try {
            return volume.readFileSync(filename);
        }
        catch (e) { return undefined; /* deleted on volume */ }
    }
}


export { LocalDBSync }