/**
 * A runner for the `pdftex.wasm` executable (as `pdflatex`).
 * Required files:
 *  * `/bin/tex/pdftex.wasm`: the program, compiled for WASI with wasi-kernel
 *  * `/bin/tex/dist.tar`: core distribution files (formats and basic fonts)
 *  * `/bin/tex/tldist.tar`: additional packages from the TeX Live repository
 */

import fs from 'fs';  /* @kremlin.native */
import { EventEmitter } from 'events';
import { ExecCore } from 'wasi-kernel/src/kernel/exec';
import { PackageManager, Resource, ResourceBundle } from 'basin-shell/src/package-mgr';
import { Volume } from '../infra/volume';


class PDFLatexBuild extends EventEmitter {
    pdflatex: PDFLatexPod
    mainTexFile: Volume.Location

    constructor(mainTexFile: Volume.Location) {
        super();
        this.mainTexFile = mainTexFile;
        this.pdflatex = new PDFLatexPod();
        this.pdflatex.packageManager.on('progress',
            (info) => this.emit('progress', {stage: 'install', info}));
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
                var out = await this.pdflatex.compile(content);
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

    watch() { /** @todo */}

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

    uploadDocument(content: string | Uint8Array, fn = '/home/doc.tex') {
        this.core.fs.writeFileSync(fn, content);
    }

    async start(fn: string = 'doc.tex', wd: string = '/home') {
        await this.prepare();
        this.core.fs.mkdirpSync(`${wd}/out`);
        return this.core.start('/bin/tex/pdftex.wasm',
            ['pdflatex', '-output-directory=out', fn], {PATH: '/bin', PWD: wd});
    }

    async compile(source: string | Uint8Array) {
        await this.prepare();
        this.uploadDocument(source);
        var rc = await this.start();

        if (rc == 0) {
            return PDFLatexPod.CompiledPDF.fromFile(
                {volume: <any>this.core.fs, filename: '/home/out/doc.pdf'});
        }
        else throw new PDFLatexPod.BuildError(rc);
    }
}

namespace PDFLatexPod {

    export class CompiledPDF {
        content: Uint8Array

        constructor(content: Uint8Array) { this.content = content; }

        saveAs(loc: Volume.Location = {volume: null, filename: "/tmp/out.pdf"}) {
            (loc.volume ?? fs).writeFileSync(loc.filename, this.content);
            return loc;
        }

        toBlob() {
            return new Blob([this.content], {type: "application/pdf"});
        }

        toURL() {
            return URL.createObjectURL(this.toBlob());
        }

        static fromFile(loc: Volume.Location) {
            return new CompiledPDF(loc.volume.readFileSync(loc.filename));
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