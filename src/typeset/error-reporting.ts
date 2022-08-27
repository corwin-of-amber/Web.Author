
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
            err.push({at, message: mo[3], pointerToLog: mo.index});
        }
        this.errors = err;
    }
}


type LogError = {at: Loc, message: string, pointerToLog: number}
type Loc = {filename: string, line: number}


export { BuildLog }