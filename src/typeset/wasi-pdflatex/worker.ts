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
        this.pdflatex.packageManager.on('progress',
            (info) => this.emit('progress', {stage: 'install', info}));

        addEventListener('message', ev => this.execute(ev.data));
    }

    emit(type: string, ev: object) {
        // @ts-ignore
        postMessage({type, ev});
    }

    async execute(command: Command) {
        try {
            var ret: any;
            switch (command.method) {
            case 'prepare':
                ret = await this.pdflatex.prepare(...<[string[]]>command.args); break;
            case 'compile':
                ret = await this.pdflatex.compile(...<[any, any]>command.args); break;
            }
            this.emit('completed', {id: command.id, status: 'ok', ret});
        }
        catch (exc) {
            this.emit('completed', {id: command.id, status: 'error', exc});
        }
    }
}


type Command = {id: number, method: string, args: any[]};

const worker = new PDFLatexWorker();
