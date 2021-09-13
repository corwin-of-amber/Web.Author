/**
 * Minimal `fs` synchronous interface.
 * (this is an abstract class in order to be able to use `isinstance`)
 */
abstract class Volume {
    path: Volume.IPath

    abstract realpathSync(fp: string): string
    abstract readdirSync(dir: string): string[]
    abstract statSync(fp: string): Volume.Stat

    abstract readFileSync(filename: string): Uint8Array
    abstract readFileSync(filename: string, encoding: Volume.Encoding): string
    abstract writeFileSync(filename: string, content: Uint8Array | string,
                           options?: Volume.WriteOptions): void

    abstract unlinkSync(filename: string): void
    abstract renameSync(oldFilename: string, newFilename: string): void

    abstract watch(filename: string, opts: any, listener: Volume.WatchListener): Volume.Watcher

    externSync?(filename: string): Volume.Location
}

namespace Volume {
    export type Stat = {isDirectory: boolean};
    export type Encoding = "utf-8";

    export interface IPath {
        join(...pathElements: string[]): string
        dirname(fp: string): string
        basename(fp: string): string
        normalize(p: string): string
    }

    export type WriteOptions = {encoding: Encoding};

    export type Location = {volume: Volume, filename: string};

    export interface Watcher {
        close(): void
    }

    export type WatchListener = (eventType: string, filename: string) => void;

    export function externSync(loc: Location) {
        return loc.volume?.externSync?.(loc.filename) ?? loc;
    }
}


/**
 * A volume obtained by referring to a subtree within a parent volume.
 * (not secure in any way, does not sanitize `..` elements in paths)
 */
class SubdirectoryVolume extends Volume {
    root: {volume: Volume, dir: string}
    path: Volume.IPath

    _watch: {policy: WatchPolicy, setup: boolean}

    constructor(volume: Volume, rootdir: string, path?: Volume.IPath) {
        super();
        this.root = {volume, dir: rootdir};
        this.path = path ?? volume.path;
        this._watch = {policy: new WatchPolicy.Individual, setup: false};
    }

    withWatchPolicy(policy: WatchPolicy) {
        this._watch = {policy, setup: false};
        return this;
    }

    get _() { return this.root.volume; }
    _abs(relpath: string) { return this.path.join(this.root.dir, relpath); }

    realpathSync(fp: string) { return fp; /** @todo */ }

    readdirSync(dir: string) { return this._.readdirSync(this._abs(dir)); }
    statSync(fp: string) { return this._.statSync(this._abs(fp)); }

    readFileSync(filename: string): Uint8Array
    readFileSync(filename: string, encoding: Volume.Encoding): string

    readFileSync(filename: string, encoding?: Volume.Encoding) {
        return <any>this._.readFileSync(this._abs(filename), encoding);
    }
    
    writeFileSync(filename: string, content: Uint8Array | string,
                  options?: Volume.WriteOptions) {
        this._.writeFileSync(this._abs(filename), content, options);
    }

    unlinkSync(filename: string) { this._.unlinkSync(this._abs(filename)); }
    renameSync(oldFilename: string, newFilename: string) {
        this._.renameSync(this._abs(oldFilename), this._abs(newFilename));
    }

    watch(filename: string, opts: any, listener: Volume.WatchListener) {
        if (!this._watch.setup) {
            this._watch.policy.setup(this.root, this.path);
            this._watch.setup = true;
        }
        return this._watch.policy.watch(filename, opts, listener);
    }

    externSync(filename: string) {
        filename = this._abs(filename);
        return this._.externSync?.(filename) ?? {volume: this._, filename};
    }
}


interface WatchPolicy {
    setup(root: {volume: Volume, dir: string}, path?: Volume.IPath): void
    watch(filename: string, opts: any, listener: Volume.WatchListener): Volume.Watcher
}

namespace WatchPolicy {

    abstract class Base {
        root: {volume: Volume, dir: string}
        path: Volume.IPath

        setup(root: {volume: Volume, dir: string}, path = root.volume.path) {
            this.root = root;
            this.path = path;
        }
    }

    /**
     * The Individual policy would create a watch for every file being
     * requested.
     */
    export class Individual extends Base implements WatchPolicy {
        watch(filename: string, opts: any, listener: Volume.WatchListener) {
            var fp = this.path.join(this.root.dir, filename);
            return this.root.volume.watch(fp, opts, listener);
        }
    }

    /**
     * The Centralized policy would create a single, recursive watch for
     * the entire directory, and filter out incoming events.
     */
    export class Centralized extends Base implements WatchPolicy {
        _master: Volume.Watcher
        _delegates = new Set<Volume.WatchListener>()

        setup(root: {volume: Volume, dir: string}, path = root.volume.path) {
            super.setup(root, path);
            this._master = root.volume.watch(root.dir, {recursive: true},
                (eventType, filename) => {
                    for (let l of this._delegates) l(eventType, filename);
                });
        }

        watch(filename: string, opts: any, listener: Volume.WatchListener) {
            var delegate = (eventType: string, eventFilename: string) => {
                if (eventFilename === filename)
                    listener(eventType, eventFilename);
            };
            this._delegates.add(delegate);
            return {
                close: () => this._delegates.delete(delegate)
            };
        }
    }

}


export { Volume, SubdirectoryVolume, WatchPolicy }