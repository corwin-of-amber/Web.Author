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

    abstract createReadStream(filename: string): ReadableStream

    abstract unlinkSync(filename: string): void
    abstract renameSync(oldFilename: string, newFilename: string): void
    abstract mkdirSync(dirname: string, opts?: any): void

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

    _notify(filename: string) { this._watch.policy.notify(filename); }

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
        this._notify(filename);
    }

    createReadStream(filename: string) {
        return this._.createReadStream(this._abs(filename));
    }

    unlinkSync(filename: string) { this._.unlinkSync(this._abs(filename)); }
    renameSync(oldFilename: string, newFilename: string) {
        this._.renameSync(this._abs(oldFilename), this._abs(newFilename));
    }
    mkdirSync(filename: string, opts?: any) {
        this._.mkdirSync(this._abs(filename), opts);
    }

    watch(filename: string, opts: any, listener: Volume.WatchListener) {
        if (!this._watch.setup) {
            this._watch.policy.setup(this);
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
    setup(volume: SubdirectoryVolume): void
    watch(filename: string, opts: any, listener: Volume.WatchListener): Volume.Watcher
    notify(filename: string): void
}

namespace WatchPolicy {

    abstract class Base {
        volume: SubdirectoryVolume

        setup(volume: SubdirectoryVolume) {
            this.volume = volume;
        }

        notify(filename: string) { }
    }

    /**
     * The Individual policy would create a watch for every file being
     * requested.
     */
    export class Individual extends Base implements WatchPolicy {
        watch(filename: string, opts: any, listener: Volume.WatchListener) {
            var fp = this.volume._abs(filename);
            return this.volume.root.volume.watch(fp, opts, listener);
        }
    }

    /**
     * This is like the `Individual` policy, but contains a polyfill for
     * `{recursive: true}` that does not exist natively on memfs.
     */
    export class IndividualWithRec extends Individual {
        watch(filename: string, opts: any, listener: Volume.WatchListener) {
            if (opts.recursive)
                this._recWatchers.add(listener);
            return super.watch(filename, opts, listener);
        }

        notify(filename: string) {
            for (let h of this._recWatchers) {
                h('change', this.volume.externSync(filename).filename);
            }
        }

        get _recWatchers(): Set<Function> {
            var ext = this.volume.externSync('/').volume;
            return (<any>ext)._volumeWRec ??= new Set<Function>();
        }
    }

    /**
     * The Centralized policy would create a single, recursive watch for
     * the entire directory, and filter out incoming events.
     */
    export class Centralized extends Base implements WatchPolicy {
        _master: Volume.Watcher
        _delegates = new Set<Volume.WatchListener>()

        setup(volume: SubdirectoryVolume) {
            super.setup(volume);
            this._master = volume.root.volume.watch(volume.root.dir, {recursive: true},
                (eventType, filename) => {
                    for (let l of this._delegates) l(eventType, filename);
                });
        }

        watch(filename: string, opts: any, listener: Volume.WatchListener) {
            var delegate = (eventType: string, eventFilename: string) => {
                if (eventFilename === filename) /** @todo or descendant thereof if `opts.recursive` */
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