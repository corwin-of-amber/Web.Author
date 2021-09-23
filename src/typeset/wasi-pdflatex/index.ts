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
import { PackageManager, Resource, ResourceBundle, DownloadProgress }
     from 'basin-shell/src/package-mgr';
import { Xz } from 'xz-extract';
     
import { Volume } from '../../infra/volume';
// @ts-ignore
import { FileWatcher } from '../../infra/fs-watch.ls';
// @ts-ignore
import { globAll, timestampAll } from '../../infra/fs-traverse.ls';
// @ts-ignore
import { LatexmkClone } from '../latexmk.ls';
import { Tlmgr } from '../../distutils/texlive/tlmgr';


class PDFLatexBuild extends EventEmitter {
    pdflatex: PDFLatexPod | PDFLatexWorkerI
    latexmk: LatexmkClone
    mainTexFile: Volume.Location
    _watch: FileWatcher

    constructor(mainTexFile: Volume.Location) {
        super();
        this.mainTexFile = mainTexFile;
        this.pdflatex = new PDFLatexWorkerI();
        // set up events
        if (this.pdflatex instanceof PDFLatexPod)
            this.pdflatex.packageManager.on('progress',
                (info) => this.emit('progress', {stage: 'install', info}));
        if (this.pdflatex instanceof EventEmitter)
            this.pdflatex.on('progress', ev => this.emit('progress', ev));

        this._watch = new FileWatcher();
        this._watch.on('change', () => this.makeWatch());
    }

    async make() {
        console.log(`%cmake ${this.mainTexFile.filename}`, 'color: green');
        this.emit('started');

        try {
            var {volume, filename} = this.mainTexFile,
                source = this._collect(volume),
                entry = new TextDecoder().decode(source[filename]),
                pkgs = this._guessRequiredPackages(entry);

            await this.pdflatex.prepare(pkgs);
            try {
                this.emit('progress', {stage: 'compile', info: {filename, done: false}})
                var out = await this.pdflatex.compile(source, filename);
            }
            finally {
                this.emit('progress', {stage: 'compile', info: {done: true}});
            }
            this.emit('intermediate', {                    
                pdf: out.pdf && PDFLatexPod.CompiledPDF.from(out.pdf),
                log: out.log && PDFLatexPod.CompiledAsset.from(out.log)
            });

            if (out.log) {
                var latexmk = this._latexmk('pdflatex', out, volume);
                
                if (latexmk.needBibtex()) {
                    try {
                        this.emit('progress', {stage: 'bibtex', info: {done: false}});
                        var bibout = await this.pdflatex.utils.bibtex.compile(out.job);
                        this._latexmk('bibtex', bibout);
                        out = await this.pdflatex.compile(source, filename);
                        this._latexmk('pdflatex', out);
                        if (latexmk.needLatex()) {
                            out = await this.pdflatex.compile(source, filename);
                        }
                    }
                    finally {
                        this.emit('progress', {stage: 'bibtex', info: {done: true}});
                    }
                }
                else if (latexmk.needLatex()) {
                    out = await this.pdflatex.compile(source, filename);
                }
            }
            
            this.emit('finished', {
                outcome: 'ok', 
                pdf: out.pdf && PDFLatexPod.CompiledPDF.from(out.pdf),
                log: out.log && PDFLatexPod.CompiledAsset.from(out.log)
            });
            return out;
        }
        catch (e) {
            if (e.log) e.log = PDFLatexPod.CompiledAsset.from(e.log);
            this.emit('finished', {outcome: 'error', error: e});
            if (e.$type !== 'BuildError') throw e;
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

    _collect(volume: Volume) {
        return Object.fromEntries(
            [...globAll(['**'], {type: 'file', exclude: ['out', '**/.*'],
                                 cwd: '', fs: volume})].map((fn: string) =>
                [fn, volume.readFileSync(fn)])
        );
    }

    _guessRequiredPackages(source: string) {
        if ((<any>window)?.DEV) return ['dev'];  // for faster dev cycles
        else {
            // this is basically a rudimentary placeholder
            var pkgs = ['latex', 'lm', 'bibtex'];
            if (source.match(/\\documentclass(\[.*?\])?{acmart}/))
                pkgs.push('acmart');
            var detect = PDFLatexPod.NANOTEX_RECOGNIZED_PKGS;
            for (let mo of source.matchAll(/\\usepackage(?:\[.*?\])?{(.*?)}/g)) {
                if (detect.has(mo[1])) pkgs.push(mo[1]);
            }
            return pkgs;
        }
    }

    _latexmk(prog: string, out: any, volume?: Volume) {
        var latexmk = (this.latexmk ??= new LatexmkClone());
        if (volume)
            latexmk.timestamps.source = timestampAll(['**'], {type: 'file', cwd: '', fs: volume});

        if (out.log)         latexmk.processLog(prog, out.log.content);
        if (out.timestamps)  latexmk.timestamps.build = out.timestamps;
            
        return latexmk;
    }
}


/**
 * This is a pile of RPC boilerplate intended to run PDFLatexPod and BibTexPod
 * in a worker.
 */
class PDFLatexWorkerI extends EventEmitter {
    worker: Worker
    _pending = new Map<number, Future>()
    _uid = 0

    _startup() {
        if (!this.worker) {
            this.worker = new Worker('./wasi-pdflatex.worker.js' /* compiled from `./worker.ts` */);
            this.worker.addEventListener('message', ev => this._handle(ev.data));
            this.worker.addEventListener('messageerror', ev => {
                console.error('messageerror', ev);
            });
        }
    }

    async _submit<T>(cmd: T & {id?: number}): Promise<any> {
        cmd.id ??= ++this._uid;
        return new Promise((resolve, reject) => {
            this._pending.set(cmd.id, {resolve, reject});
            this.worker.postMessage(cmd);
        });
    }

    _handle({type, ev}: MessageFromWorker) {
        switch (type) {
        case 'completed':
            var fut = this._pending.get(ev.id);
            if (fut) {
                this._pending.delete(ev.id);
                switch (ev.status) {
                case 'ok': fut.resolve(ev.ret); break;
                default:   fut.reject(ev.exc); break;
                }
            }
            break;
        case 'progress':
            this.emit('progress', ev);
        }
    }

    async prepare(packages: string[] = []): Promise<void> {
        this._startup();
        return await this._submit({method: 'prepare', args: [packages]});
    }

    async compile(source: PDFLatexPod.CompileInput, main?: string, wd?: string): 
            Promise<PDFLatexPod.CompileRet> {
        this._startup();
        return await this._submit({method: 'compile', args: [source, main, wd]});
    }

    utils = {
        bibtex: {
            compile: async (job: string, wd?: string) => {
                return await this._submit(
                    {method: 'bibtex:compile', args: [job, wd]}
                ) as BibTexPod.CompileRet;
            }
        }
    }
}

type MessageFromWorker = {type: 'completed' | 'progress',
                          ev: {id: number, status: string,
                               ret: any, exc: any}};
type Future = {resolve: (v: any) => void, reject: (err: any) => void};


class PDFLatexPod {
    core: ExecCore
    packageManager: PackageManager
    tlmgr: Tlmgr

    _ready: Promise<void>
    _installed = new Set<string>()

    mainTex: string = '/home/doc.tex'
    opts = {outdir: 'out', synctex: 1}

    utils: {bibtex: BibTexPod}

    constructor() {
        this.core = new ExecCore({stdin: false});
        this.core.on('stream:out', ({fd, data}) =>
            console.log(fd, new TextDecoder().decode(data)));

        this.packageManager = new PackageManager(this.core.fs);
        this.tlmgr = new Tlmgr();

        this.utils = {
            bibtex: new BibTexPod(this.core, this.opts)
        };
    }

    prepare(packages: string[] = []) {
        if (!this._ready || packages.some(pkg => !this._installed.has(pkg)))
            this._ready = this._prepare(packages);
        return this._ready;
    }

    async _prepare(packages: string[]) {
        packages = packages.filter(pkg => !this._installed.has(pkg));
        if (!this._installed.has('texdist'))
            await this.packageManager.install(PDFLatexPod.texdist);
        if (packages.length > 0)
            await this.packageManager.install(
                await PDFLatexPod.bundleOf(packages, this.tlmgr));

        this._installed.add('texdist');
        for (let pkg of packages) this._installed.add(pkg);
    }

    uploadDocument(content: string | Uint8Array, fn = this.mainTex, wd = '/home') {
        fn = path.join(wd, fn);
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

    async compile(source: PDFLatexPod.CompileInput, main?: string, wd?: string)
            : Promise<PDFLatexPod.CompileRet> {
        await this.prepare();
        for (let [fn, content] of Object.entries(source))
            this.uploadDocument(content, fn);
        var rc = await this.start(main, wd);

        var volume = <unknown>this.core.fs as Volume,
            outdir = path.resolve('/home', this.opts.outdir),
            file = (fn: string) => ({volume, filename: `${outdir}/${fn}`}),
            job = main ? path.basename(main).replace(/\.(tex|ltx)$/, '') : 'doc',
            log = PDFLatexPod.CompiledAsset.fromFileMaybe(file(`${job}.log`));

        if (rc == 0) {
            var timestamps = timestampAll(['**'], {type: 'file', cwd: '/home', fs: volume});
            return {
                job,
                pdf: PDFLatexPod.CompiledPDF.fromFile(file(`${job}.pdf`))
                        .withSyncTeXMaybe(file(`${job}.synctex.gz`)),
                log, timestamps
            };
        }
        else throw new PDFLatexPod.BuildError(rc).withLog(log);
    }
}


class XzResource extends Resource {
    async blob(progress?: (p: DownloadProgress) => void) {
        var compressed = await (await super.blob(progress)).arrayBuffer(),
            xz = new Xz(new Uint8Array(compressed));
        
        var unpacked = new Uint8Array(xz.decompressBlock());
        return new Blob([unpacked]);
    }
}


namespace PDFLatexPod {

    export type CompileInput = {[fn: string]: string | Uint8Array};
    export type CompileRet = {job: string, pdf: CompiledPDF, log?: CompiledAsset, timestamps?: any};

    type This<T extends new(...args: any) => any> = {
        new(...args: ConstructorParameters<T>): any
    } & Pick<T, keyof T>;

    export class CompiledAsset {
        content: Uint8Array
        contentType: string = "application/octet-stream"

        constructor(content: Uint8Array) { this.content = content; }

        saveAs(loc: Volume.Location) {
            const ifs = loc.volume ?? fs;
            ifs.mkdirSync((loc.volume?.path ?? path).dirname(loc.filename), {recursive: true});
            ifs.writeFileSync(loc.filename, this.content);
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

        static fromFileMaybe<T extends This<typeof CompiledAsset>>
                (this: T, loc: Volume.Location): InstanceType<T> {
            try { return this.fromFile(loc); }
            catch { return undefined; }
        }

        static from(data: any) {
            if (data instanceof CompiledAsset) return data;
            else return new CompiledAsset(data.content);
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

        static from(data: any) {
            if (data instanceof CompiledPDF) return data;
            else {
                var c = new CompiledPDF(data.content);
                if (data.synctex) c.synctex = CompiledAsset.from(data.synctex);
                return c;
            }
        }
    }

    export class BuildError {
        $type = 'BuildError'
        prog = 'pdflatex'
        code: number
        log?: CompiledAsset
        constructor(code: number) {
            this.code = code;
        }
        withLog(log: CompiledAsset) {
            this.log = log;
            return this;
        }
    }

    export const texdist: ResourceBundle = {
        '/bin/pdftex': '#!/bin/tex/pdftex.wasm',
        '/bin/pdflatex': '#!/bin/tex/pdftex.wasm',
        '/bin/bibtex': '#!/bin/tex/bibtex.wasm',
        '/bin/texmf.cnf': new Resource('/bin/tex/texmf.cnf'),
        '/dist/': new Resource('/bin/tex/dist.tar'),
        '/dist/pdftex.map': new Resource('/bin/tex/pdftex.map'),
        //'/tldist/': new Resource('/bin/tex/tldist.tar')
    };

    export const NANOTEX_RECOGNIZED_PKGS = new Set(
        ['geometry', 'adjustbox', 'wrapfig', 'menukeys']);

    const NANOTEX_BASE = '/bin/tlnet',
          NANOTEX_DEV = '/bin/tex/tldist.tar',
          NANOTEX_FMT = Object.fromEntries(['lm', 'amsfonts', 'pgf']   // these are too large for LZMA2-js
                                           .map(x => [x, 'tar']));

    export async function bundleOf(joy: string[], tlmgr: Tlmgr) {
        var pkgs = await tlmgr.collect(joy);
        return {
            '/tldist/': [
                ...pkgs.map(nm =>
                    nm == 'dev' ? new Resource(NANOTEX_DEV) :
                        NANOTEX_FMT[nm] == 'tar' ?
                            new Resource(`${NANOTEX_BASE}/${nm}.tar`) :
                            new XzResource(`${NANOTEX_BASE}/${nm}.tar.xz`))
            ]
        } as ResourceBundle;
    }

}


class BibTexPod {
    core: ExecCore
    opts: {outdir: string}

    stdout = new BibTexPod.Stdout

    constructor(core: ExecCore, opts: {outdir: string}) {
        this.core = core;
        this.opts = opts;
        this.core.on('stream:out', ({fd, data}) => this.stdout.push(data));
    }

    async start(job: string, wd: string = '/home') {
        var args = [path.join(this.opts.outdir, job)];
        this.stdout.clear();
        return this.core.start('/bin/tex/bibtex.wasm',
            ['/bin/bibtex', ...args], {PATH: '/bin', PWD: wd});
    }

    async compile(job: string, wd: string = '/home') {
        var rc = await this.start(job, wd);

        var log = new PDFLatexPod.CompiledAsset(this.stdout.buffer);

        if (rc == 0)
            return {log}
        else
            throw new BibTexPod.BuildError(rc).withLog(log);
    }
}

namespace BibTexPod {
    export type CompileRet = {log: PDFLatexPod.CompiledAsset};

    export class BuildError extends PDFLatexPod.BuildError {
        prog = 'bibtex'
    }

    export class Stdout {
        _buffer: Uint8Array[] = []
        clear() { this._buffer = []; }
        push(data: Uint8Array) { this._buffer.push(data); }
        get buffer() { return concat(this._buffer); }
    }

    // Uint8Array concat boilerplate
    function concat(arrays: Uint8Array[]) {
        let totalLength = arrays.reduce((acc, value) => acc + value.length, 0),
            result = new Uint8Array(totalLength), pos = 0;
        for (let array of arrays) {
            result.set(array, pos);
            pos += array.length;
        }
        return result;
    }
}


export { PDFLatexBuild, PDFLatexPod }