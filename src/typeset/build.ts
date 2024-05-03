
class CompiledAsset {
    content: Uint8Array
    contentType: string = "application/octet-stream"

    constructor(content: Uint8Array) { this.content = content; }

    toText() {
        return new TextDecoder().decode(this.content);
    }
}


export { CompiledAsset }