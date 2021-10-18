import { ExecCore } from 'wasi-kernel/src/kernel/exec';
import { Resource, DownloadProgress } from 'basin-shell/src/package-mgr';

import { concat } from '../../infra/binary-data';


class CacheableResource extends Resource {
    ['constructor']: typeof CacheableResource

    async blob(progress?: (p: DownloadProgress) => void) {
        var data = await this.cache.from(this.uri, progress) ??
                   this.cache.into(this.uri, await super.blob(progress));

        return data instanceof Blob
            ? data : new Blob([await data.arrayBuffer()]);
    }

    get cache() {
        return this.constructor._cache ??=
            new ResourceCache(this.constructor.cacheName); 
    }

    static cacheName = 'tlarchive'
    static _cache: ResourceCache
}


class XzResource extends CacheableResource {
    async blob(progress?: (p: DownloadProgress) => void) {
        var compressed = await (await super.blob(progress)).arrayBuffer(),
            decompressed = await XzResource.unpackSync(new Uint8Array(compressed));

        return new Blob([decompressed]);
    }

    /** unpacking is synchronous; `async` is only needed for fetching the `.wasm` */
    static async unpackSync(ui8a: Uint8Array) {
        var xz = new ExecCore({stdin: false}),
            buf = {1: [], 2: []}, h = ({fd, data}) => buf[fd]?.push(data);
        xz.on('stream:out', h);
        xz.cached = this._wasm_cache;
        xz.fs.writeFileSync('/dev/stdin', ui8a);
        var rc = await xz.start('/bin/xzminidec.wasm');
        if (rc == 0) return concat(buf[1]);
        else throw new Error('[xz] ' + 
            buf[2].length ? new TextDecoder().decode(concat(buf[2])) : 'unknown error');
    }

    /** @note reusing the ExecCore itself doesn't work, somehow (wasi-kernel bug?) */
    static _wasm_cache = new Map<string, Promise<WebAssembly.Module>>();
}


/**
 * Stores some downloaded archives for later use.
 * This allows better control than relying on the browser's HTTP(S) cache.
 * @todo cache should be cleared at some point.
 * @todo probably should be moved to basin-shell.
 */
class ResourceCache {
    _cache: Promise<Cache>

    constructor(cacheName: string, rev: number | string = '*') {
        this._cache = (async () => {
            var c = await caches.open(cacheName);
            if (!this._isCacheable()) return c; // bail
            // clear cache if not same revision as given.
            // using special URL `/rev/##` as an indicator of a valid cache.
            var ind = `/rev/${rev}`;
            if (!await c.match(ind)) {
                await this._clear(c);
                c.put(ind, new Response(new Blob([]))); /* dummy entry */
            }
            return c;
        })();
    }

    async from(uri: string, progress: (p: DownloadProgress) => void) {
        var entry = await (await this._cache).match(uri);
        if (entry) progress({uri, total: 1, downloaded: 1}); /* dummy entry */
        return entry;
    }

    into(uri: string, blob: Blob) {
        if (this._isCacheable())
            (async () => (await this._cache).put(uri, new Response(blob)))();
        return blob;
    }

    async clear() { await this._clear(await this._cache); }

    async _clear(c: Cache) {
        for (let k of await c.keys()) await c.delete(k);
    }

    _isCacheable() { return ['http:', 'https:'].includes(location.protocol); }
}


export { XzResource, ResourceCache }