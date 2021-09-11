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

    externSync?(filename: string): Volume.Location
}

namespace Volume {
    export type Stat = {isDirectory: boolean};
    export type Encoding = "utf-8";

    export interface IPath {
        join(...pathElements: string[]): string
        dirname(fp: string): string
        basename(fp: string): string
    }

    export type WriteOptions = {encoding: Encoding};

    export type Location = {volume: Volume, filename: string};

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

    constructor(volume: Volume, rootdir: string, path?: Volume.IPath) {
        super();
        this.root = {volume, dir: rootdir};
        this.path = path ?? volume.path;
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

    externSync(filename: string) {
        filename = this._abs(filename);
        return this._.externSync?.(filename) ?? {volume: this._, filename};
    }
}


export { Volume, SubdirectoryVolume }