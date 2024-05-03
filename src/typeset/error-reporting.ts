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
    errors: LogError[]

    constructor(text: string) {
        this.text = text;
        this.locateErrors();
    }

    locateErrors() {
        let err = [];
        for (let mo of this.text.matchAll(/^([./]\S+):(\d+):\s(.*)/mg)) {
            let at = {filename: mo[1], line: +mo[2]};
            err.push({at, message: mo[3], offsetInLog: mo.index});
        }
        this.errors = err;
    }
}


type LogError = {at: Loc, message: string, offsetInLog: number}
type Loc = {filename: string, line: number}


export { BuildError, BuildLog }