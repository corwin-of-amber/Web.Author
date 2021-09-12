/**
 * A runner for the `pdftex.wasm` executable (as `pdflatex`).
 * Required files:
 *  * `/bin/tex/pdftex.wasm`: the program, compiled for WASI with wasi-kernel
 *  * `/bin/tex/dist.tar`: core distribution files (formats and basic fonts)
 *  * `/bin/tex/tldist.tar`: additional packages from the TeX Live repository
 */

import fs from 'fs';  /* @kremlin.native */
import path from 'path';
import { EventEmitter } from 'events';
import { ExecCore } from 'wasi-kernel/src/kernel/exec';
import { PackageManager, Resource, ResourceBundle } from 'basin-shell/src/package-mgr';
import { Volume } from '../infra/volume';
// @ts-ignore
import { FileWatcher } from '../infra/fs-watch.ls';


class PDFLatexBuild extends EventEmitter {
    pdflatex: PDFLatexPod
    mainTexFile: Volume.Location
    _watch: FileWatcher

    constructor(mainTexFile: Volume.Location) {
        super();
        this.mainTexFile = mainTexFile;
        this.pdflatex = new PDFLatexPod();
        this.pdflatex.packageManager.on('progress',
            (info) => this.emit('progress', {stage: 'install', info}));

        this._watch = new FileWatcher();
        this._watch.on('change', () => this.makeWatch());
    }

    async make() {
        console.log(`%cmake ${this.mainTexFile.filename}`, 'color: green');
        this.emit('started');

        try {
            var {volume, filename} = this.mainTexFile,
                content = volume.readFileSync(filename);
            await this.pdflatex.prepare();
            try {
                this.emit('progress', {stage: 'compile', info: {filename, done: false}})
                var out = await this.pdflatex.compile(content, `/home/${volume.path.basename(filename)}`);
            }
            finally {
                this.emit('progress', {stage: 'compile', info: {done: true}});
            }
            this.emit('finished', {outcome: 'ok', pdf: out});
            return out;
        }
        catch (e) {
            this.emit('finished', {outcome: 'error', error: e});
            if (!(e instanceof PDFLatexPod.BuildError)) throw e;
        }
    }

    clean() { /** @todo */ }

    async remake() {
        this.clean();
        return await this.make();
    }

    watch() {
        var {volume, filename} = this.mainTexFile;
        this._watch.single(filename, {fs: volume});
    }

    async makeWatch() {
        var res = await this.make();
        this.watch();
        return res;
    }
}


class PDFLatexPod {
    core: ExecCore
    packageManager: PackageManager

    _prepared: Promise<void>

    mainTex: string = '/home/doc.tex'
    opts = {outdir: 'out', synctex: 1}

    constructor() {
        this.core = new ExecCore({stdin: false});
        this.core.on('stream:out', ({fd, data}) =>
            /** @todo collect in some log */
            console.log(fd, new TextDecoder().decode(data)));

        this.packageManager = new PackageManager(this.core.fs);
    }

    prepare() {
        return (this._prepared ??=
            this.packageManager.install(PDFLatexPod.texdist));
    }

    uploadDocument(content: string | Uint8Array, fn = this.mainTex) {
        this.core.fs.mkdirSync(path.dirname(fn), {recursive: true});
        this.core.fs.writeFileSync(fn, content);
        this.mainTex = fn;
    }

    async start(fn: string = this.mainTex, wd: string = '/home') {
        await this.prepare();
        this.core.fs.mkdirSync(path.resolve(wd, this.opts.outdir), {recursive: true});
        var flags = [
            `-output-directory=${this.opts.outdir}`,
            `-synctex=${this.opts.synctex}`
        ]
        return this.core.start('/bin/tex/pdftex.wasm',
            ['pdflatex', ...flags, fn], {PATH: '/bin', PWD: wd});
    }

    async compile(source: string | Uint8Array, fn?: string) {
        await this.prepare();
        this.uploadDocument(source, fn);
        var rc = await this.start();

        if (rc == 0) {
            var volume = <unknown>this.core.fs as Volume,
                outdir = path.resolve('/home', this.opts.outdir),
                file = (fn: string) => ({volume, filename: `${outdir}/${fn}`}),
                job = fn ? path.basename(fn).replace(/\.tex$/, '') : 'doc';
            return PDFLatexPod.CompiledPDF.fromFile(file(`${job}.pdf`))
                .withSyncTeXMaybe(file(`${job}.synctex.gz`));
        }
        else throw new PDFLatexPod.BuildError(rc);
    }
}

namespace PDFLatexPod {

    type This<T extends new(...args: any) => any> = {
        new(...args: ConstructorParameters<T>): any
    } & Pick<T, keyof T>;

    export class CompiledAsset {
        content: Uint8Array
        contentType: string = "application/octet-stream"

        constructor(content: Uint8Array) { this.content = content; }

        saveAs(loc: Volume.Location) {
            (loc.volume ?? fs).writeFileSync(loc.filename, this.content);
            return loc;
        }

        toBlob() {
            return new Blob([this.content], {type: this.contentType});
        }

        toURL() {
            return URL.createObjectURL(this.toBlob());
        }

        static fromFile<T extends This<typeof CompiledAsset>>
                (this: T, loc: Volume.Location): InstanceType<T> {
            return new this(loc.volume.readFileSync(loc.filename));
        }
    }

    export class CompiledPDF extends CompiledAsset {
        contentType = "application/pdf"
        synctex: CompiledAsset

        saveAs(loc: Volume.Location = {volume: null, filename: "/tmp/out.pdf"}) {
            return super.saveAs(loc);
        }

        withSyncTeX(loc: Volume.Location) {
            this.synctex = CompiledAsset.fromFile(loc);
            return this;
        }

        withSyncTeXMaybe(loc: Volume.Location) {
            try { return this.withSyncTeX(loc); }
            catch { return this; }
        }
    }

    export class BuildError {
        code: number
        constructor(code: number) {
            this.code = code;
        }
    }

    export const texdist: ResourceBundle = {
        '/bin/pdftex': '#!/bin/tex/pdftex.wasm',
        '/bin/pdflatex': '#!/bin/tex/pdftex.wasm',
        '/bin/texmf.cnf': new Resource('/bin/tex/texmf.cnf'),
        '/dist/': new Resource('/bin/tex/dist.tar'),
        '/tldist/': new Resource('/bin/tex/tldist.tar')
    };

}


export { PDFLatexBuild, PDFLatexPod }