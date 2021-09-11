/**
 * A runner for the `pdftex.wasm` executable (as `pdflatex`).
 * Required files:
 *  * `/bin/tex/pdftex.wasm`: the program, compiled for WASI with wasi-kernel
 *  * `/bin/tex/dist.tar`: core distribution files (formats and basic fonts)
 *  * `/bin/tex/tldist.tar`: additional packages from the TeX Live repository
 */

import fs from 'fs';  /* @kremlin.native */
import { ExecCore } from 'wasi-kernel/src/kernel/exec';
import { PackageManager, Resource, ResourceBundle } from 'basin-shell/src/package-mgr';


class PDFLatexBuild {
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
        return this.packageManager.install(PDFLatexBuild.texdist);
    }

    uploadDocument(content: string) {
        this.core.fs.writeFileSync('/home/doc.tex', content);
    }

    async start() {
        await (this._prepared ??= this.prepare());
        return this.core.start('/bin/tex/pdftex.wasm',
            ['pdflatex', 'doc.tex'], {PATH: '/bin', PWD: '/home'});
    }

    async build(source: string) {
        await (this._prepared ??= this.prepare());
        this.uploadDocument(source);
        var rc = await this.start();

        if (rc == 0) {
            return PDFLatexBuild.CompiledPDF.fromFile('/home/doc.pdf', this.core.fs);
        }        
    }
}

namespace PDFLatexBuild {

    export class CompiledPDF {
        content: Uint8Array

        constructor(content: Uint8Array) { this.content = content; }

        saveAs(filename = "/tmp/out.pdf", ifs = fs) {
            ifs.writeFileSync(filename, this.content);
            return filename;
        }

        static fromFile(filename: string, ifs: any = fs) {
            return new CompiledPDF(ifs.readFileSync(filename));
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


export { PDFLatexBuild }