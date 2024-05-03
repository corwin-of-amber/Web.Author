import { CompiledAsset } from "./build"


class BuildError {
    $type = 'BuildError'
    prog: string
    code: number
    log?: CompiledAsset
    out?: CompiledAsset

    constructor(prog: string, code: number) {
        this.prog = prog;
        this.code = code;
    }

    withLog(log: CompiledAsset, out?: CompiledAsset) {
        this.log = log;
        if (out) this.out = out;
        return this;
    }
}


class BuildLog {
    text: string
    log?: CompiledAsset
    errors: LogError[]

    constructor(text: string, log?: CompiledAsset) {
        this.text = text;
        this.log = log;
        this.locateErrors();
    }

    locateErrors() {
        let err: LogError[] = [];
        for (let mo of this.text.matchAll(/^([./]\S+):(\d+):\s(.*)/mg)) {
            let at = {filename: mo[1], line: +mo[2]};
            err.push({at, message: mo[3],
                      inLog: {log: this.log, offset: mo.index}});
        }
        this.errors = err;
    }
}


type LogError = {at: Loc, message: string, inLog: {log?: CompiledAsset, offset: number}}
type Loc = {filename: string, line: number}


export { BuildError, BuildLog }