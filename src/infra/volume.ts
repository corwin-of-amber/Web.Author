/**
 * Minimal `fs` synchronous interface.
 */
interface Volume {
    path: Volume.IPath

    realpathSync(fp: string): string
    readdirSync(dir: string): string[]
    statSync(fp: string): Volume.Stat

    readFileSync(filename: string): Uint8Array
    readFileSync(filename: string, encoding: Volume.Encoding): string
    writeFileSync(filename: string, content: Uint8Array | string,
                  options?: Volume.WriteOptions): void

    unlinkSync(filename: string): void
    renameSync(oldFilename: string, newFilename: string): void
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
}


/**
 * A volume obtained by referring to a subtree within a parent volume.
 * (not secure in any way, does not sanitize `..` elements in paths)
 */
class SubdirectoryVolume implements Volume {
    root: {volume: Volume, dir: string}
    path: Volume.IPath

    constructor(volume: Volume, rootdir: string, path?: Volume.IPath) {
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
        this.renameSync(this._abs(oldFilename), this._abs(newFilename));
    }
}


export { Volume, SubdirectoryVolume }