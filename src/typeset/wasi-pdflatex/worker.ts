/* Kremlin is a bit incomplete at the moment */
if (typeof Buffer == 'undefined')
    global.Buffer = require('buffer').Buffer;
if (!process.nextTick) {
    Object.assign(process, require('process'));
    //process.nextTick = (f, ...args) -> f(...args) # risky!!
}


import { PDFLatexPod } from './index';


class PDFLatexWorker {
    pdflatex: PDFLatexPod = new PDFLatexPod()

    constructor() {
        this.pdflatex.on('progress', ev => this.emit('progress', ev));

        addEventListener('message', ev => this.execute(ev.data));
    }

    emit(type: string, ev: object) {
        (<Client><unknown> /* ?? */ self).postMessage({type, ev});
    }

    async execute(command: Command) {
        try {
            var {method, args} = command, ret: any;
            switch (method) {
            case 'prepare':
                ret = await this.pdflatex.prepare(...<[string[]]>args); break;
            case 'compile':
                ret = await this.pdflatex.compile(...<[any, any]>args); break;
            case 'bibtex:compile':
                ret = await this.pdflatex.utils.bibtex.compile(...<[string, string]>args); break;
            }
            this.emit('completed', {id: command.id, status: 'ok', ret});
        }
        catch (exc) {
            this.emit('completed', {id: command.id, status: 'error', exc});
        }
    }
}


type Command = {id: number, method: string, args: any[]};

// @ts-ignore
self.worker = new PDFLatexWorker();
