import { Volume } from "../infra/volume";

class CompiledAsset {
    content: Uint8Array
    contentType: string = "application/octet-stream"

    constructor(content: Uint8Array) { this.content = content; }

    toText() {
        return new TextDecoder().decode(this.content);
    }
}

class CompiledAssetFile extends CompiledAsset {
    loc: Volume.Location

    withLoc(loc: Volume.Location) {
        this.loc = loc;
        return this;
    }

    static fromFile(loc: Volume.Location) {
        return new this(loc.volume.readFileSync(loc.filename))
                .withLoc(loc);
    }
}


export { CompiledAsset, CompiledAssetFile }