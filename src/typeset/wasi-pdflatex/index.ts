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

import { PackageRepository } from '../../../packages/nanotex/lib/repo.js';
import { PackageRequirements } from '../../../packages/nanotex/lib/predict.js';
          
import { Volume } from '../../infra/volume';
import { concat } from '../../infra/binary-data';
// @ts-ignore
import { FileWatcher } from '../../infra/fs-watch.ls';
// @ts-ignore
import { globAll, timestampAll } from '../../infra/fs-traverse.ls';
// @ts-ignore
import { LatexmkClone } from '../latexmk.ls';
import { XzResource } from './assets';



class PDFLatexBuild extends EventEmitter {
    pdflatex: PDFLatexPod | PDFLatexWorkerI
    latexmk: LatexmkClone
    mainTexFile: Volume.Location
    _watch: FileWatcher

    nanotex: PackageRepository

    constructor(mainTexFile: Volume.Location) {
        super();
        this.mainTexFile = mainTexFile;
        this.pdflatex = new PDFLatexWorkerI();
        this.pdflatex.on('progress', ev => this.emit('progress', ev));

        this._watch = new FileWatcher();
        this._watch.on('change', () => this.makeWatch());

        this.nanotex = new PackageRepository();
        this.nanotex.opts.dbfn = 'http:/packages/nanotex/data/texlive2021-pkg-info.json';
    }

    setMain(mainTexFile: Volume.Location) {
        this.mainTexFile = mainTexFile;
    }

    async make() {
        console.log(`%cmake ${this.mainTexFile.filename}`, 'color: green');
        this.emit('started');

        try {
            var {volume, filename} = this.mainTexFile,
                source = this._collect(volume),
                pkgs = await this._guessRequiredPackages(source);

            await this._stage('prepare', {}, () =>
                this.pdflatex.prepare(pkgs)
            );
            var out = await this._stage('compile', {filename}, () =>
                this.pdflatex.compile(source, filename)
            );
            this.emit('intermediate', {                    
                pdf: out.pdf && PDFLatexPod.CompiledPDF.from(out.pdf),
                log: out.log && PDFLatexPod.CompiledAsset.from(out.log)
            });

            if (out.log) {
                var latexmk = this._latexmk('pdflatex', out, volume);
                if (latexmk.needBibtex()) {
                    await this._stage('bibtex', {}, async () => {
                        var bibout = await this.pdflatex.utils.bibtex.compile(out.job);
                        this._latexmk('bibtex', bibout);
                        out = await this.pdflatex.compile(source, filename);
                        this._latexmk('pdflatex', out);
                        if (latexmk.needLatex()) {
                            out = await this.pdflatex.compile(source, filename);
                        }
                    });
                }
                else if (latexmk.needLatex()) {
                    out = await this._stage('recompile', {filename}, () =>
                        this.pdflatex.compile(source, filename)
                    );
                }
            }
            
            this.emit('finished', {
                outcome: 'ok', 
                pdf: out.pdf && PDFLatexPod.CompiledPDF.from(out.pdf),
                log: out.log && PDFLatexPod.CompiledAsset.from(out.log),
                out: out.out && PDFLatexPod.CompiledAsset.from(out.out)
            });
            return out;
        }
        catch (e) {
            if (e.log) e.log = PDFLatexPod.CompiledAsset.from(e.log);
            if (e.out) e.out = PDFLatexPod.CompiledAsset.from(e.out);
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

    unwatch() {
        this._watch.clear();
    }

    async makeWatch() {
        var res = await this.make();
        this.watch();
        return res;
    }

    async _stage<I extends {}, T>(name: string, info: I, op: () => Promise<T>) {
        try {
            this.emit('progress', {stage: name, info: {...info, done: false}});
            return await op();
        }
        finally {
            this.emit('progress', {stage: name, info: {...info, done: true}});
        }
    }

    _collect(volume: Volume): PDFLatexBuild.SourceFiles {
        return Object.fromEntries(
            [...globAll(['**'], {type: 'file', exclude: ['out', '**/.*'],
                                 cwd: '', fs: volume})].map((fn: string) =>
                [fn, volume.readFileSync(fn)])
        );
    }

    async _guessRequiredPackages(source: PDFLatexBuild.SourceFiles) {
        if (localStorage['toxin-dist-dev']) return ['dev'];  // for faster dev cycles
        else {
            await this.nanotex.db.open();
            let texSources = Object.entries(source).map(([fn, content]) =>
                fn.match(/[.](tex|ltx|sty)$/) ?
                    new TextDecoder().decode(content) : undefined
            ).filter(x => x);

            return ['some-fonts', 'ls-R',
                    ...new PackageRequirements(this.nanotex.db)
                        .predictDeps(texSources)];
        }
    }

    *_extractImports(source: string): Generator<string, void> {
        // this is kind of a "best effort"
        for (let mo of source.matchAll(/\\documentclass(?:\[.*?\])?{(.*?)}/g))
            yield mo[1].trim();
        for (let mo of source.matchAll(/\\usepackage(?:\[.*?\])?{(.*?)}/g)) {
            for (let s of mo[1].split(','))
                yield s.trim();
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

namespace PDFLatexBuild {
    export type SourceFiles = {[fn: string]: Uint8Array};
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
            this.emit('progress', {stage: 'load', info: {}});
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


class PDFLatexPod extends EventEmitter {
    core: ExecCore
    packageManager: PackageManager
    tlmgr: PDFLatexPod.NanoTexMgr

    _ready: Promise<void>
    _installed = new Set<string>()

    mainTex: string = '/home/doc.tex'
    opts = {outdir: 'out', synctex: 1, interaction: 'nonstopmode'}
    stdout = new Stdout

    utils: {bibtex: BibTexPod}

    constructor() {
        super();
        this.core = new ExecCore({stdin: false});
        this.core.on('stream:out', ({fd, data}) => {
            this.stdout.push(data);
            console.log(fd, new TextDecoder().decode(data));
        });

        this.packageManager = new PackageManager(this.core.fs);
        this.tlmgr = new PDFLatexPod.NanoTexMgr();

        this.utils = {
            bibtex: new BibTexPod(this.core, this.opts)
        };
    }

    prepare(packages: string[] = []) {
        this.stdout.clear();
        if (!this._ready || packages.some(pkg => !this._installed.has(pkg)))
            this._ready = this._prepare(packages);
        return this._ready;
    }

    async _prepare(packages: string[]) {
        packages = packages.filter(pkg => !this._installed.has(pkg));
        if (!this._installed.has('texdist'))
            await this.packageManager.install(PDFLatexPod.texdist);
        if (packages.length > 0) {
            let pkgs = await this.tlmgr.bundleOf(packages),
                uris = (pkgs['/tldist/'] as Resource[]).map(rc => rc.uri);
            await this._installWithProgress(pkgs, ev =>
                this.emit('progress', {stage: 'install', info: {...ev,
                    task: {index: uris.indexOf(ev.uri) + 1, total: uris.length}}}));
        }

        this._installed.add('texdist');
        for (let pkg of packages) this._installed.add(pkg);
    }

    async _installWithProgress(pkgs: ResourceBundle, progress: (ev: {uri: string}) => void) {
        this.packageManager.on('progress', progress);
        try {
            await this.packageManager.install(pkgs);
        }
        finally { this.packageManager.off('progress', progress); }
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
            `-synctex=${this.opts.synctex}`,
            `-interaction=${this.opts.interaction}`,
            '-file-line-error'
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
            log = PDFLatexPod.CompiledAsset.fromFileMaybe(file(`${job}.log`)),
            out = new PDFLatexPod.CompiledAsset(this.stdout.buffer);

        if (rc == 0) {
            var timestamps = timestampAll(['**'], {type: 'file', cwd: '/home', fs: volume});
            return {
                job,
                pdf: PDFLatexPod.CompiledPDF.fromFile(file(`${job}.pdf`))
                        .withSyncTeXMaybe(file(`${job}.synctex.gz`)),
                log, out, timestamps
            };
        }
        else throw new PDFLatexPod.BuildError(rc).withLog(log, out);
    }
}



namespace PDFLatexPod {

    export type CompileInput = {[fn: string]: string | Uint8Array};
    export type CompileRet = {
        job: string,
        pdf: CompiledPDF,
        log?: CompiledAsset,
        out?: CompiledAsset,
        timestamps?: any
    };

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

        toText() {
            return new TextDecoder().decode(this.content);
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
        out?: CompiledAsset
        constructor(code: number) {
            this.code = code;
        }
        withLog(log: CompiledAsset, out?: CompiledAsset) {
            this.log = log;
            if (out) this.out = out;
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
    };

    const NANOTEX_BASE = '/packages/nanotex/extra/pkgs',
          NANOTEX_DEV = '/bin/tex/tldist.tar',
          TLNET_MIRROR = process.versions?.nw ?
            'https://ftp.tu-chemnitz.de/pub/tug/historic/systems/texlive/2021/tlnet-final/archive' :
            'https://pl.cs.technion.ac.il/mirror/texlive2021/archive' /* CORS version */;

    export const NANOTEX_EXTRA_PKGS = ['some-fonts', 'ls-R'];

    export class NanoTexMgr {
        async bundleOf(joy: string[]) {
            console.log('%c[nanotex] installing from tlmgr:', 'color: green', joy);
            return {
                '/tldist/': joy.map(nm =>
                    nm == 'dev' ? new Resource(NANOTEX_DEV) :
                    NANOTEX_EXTRA_PKGS.includes(nm) ?
                        new Resource(`${NANOTEX_BASE}/${nm}.tar`) :
                        new XzResource(`${TLNET_MIRROR}/${nm}.tar.xz`))
            } as ResourceBundle;
        }
    }

}


class BibTexPod {
    core: ExecCore
    opts: {outdir: string}

    stdout = new Stdout

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
}

export class Stdout {
    _buffer: Uint8Array[] = []
    clear() { this._buffer = []; }
    push(data: Uint8Array) { this._buffer.push(data); }
    get buffer() { return concat(this._buffer); }
}



export { PDFLatexBuild, PDFLatexPod }