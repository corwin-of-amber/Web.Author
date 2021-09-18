import fs from 'fs';      /** @kremlin.native */
import path from 'path';  /** @kremlin.native */
import pathShim from 'path';  // for browser environment
import { JSONKeyedMap } from './keyed-map';
import { Volume, SubdirectoryVolume, WatchPolicy } from './volume';


class VolumeFactory {
    schemes = new Map<string, VolumeScheme>()
    memo = new JSONKeyedMap<VolumeFactory.Locator, Volume>()
 
    get(locator: VolumeFactory.Locator) {
        locator = {scheme: locator.scheme, path: locator.path}; // normalize
        var vol = this.memo.get(locator);
        if (!vol) {
            vol = this._gen(locator);
            this.memo.set(locator, vol);
        }
        return vol;
    }

    describe(vol: Volume) {
        for (let [k,v] of this.memo.entries()) {
            if (v === vol) return k;
        }
        console.warn('unable to describe this volume:', vol);
    }

    _gen(locator: VolumeFactory.Locator) {
        var scheme = this.schemes.get(locator.scheme);
        if (!locator) throw new Error(`unknown scheme for location '${locator.scheme}:${locator.path}`);
        return scheme.createVolumeFromPath(locator.path);
    }
}

namespace VolumeFactory {
    export type Locator = {scheme: string, path: string}

    export const instance = new VolumeFactory
}


interface VolumeScheme<V extends Volume = Volume> {
    createVolumeFromPath(p: string): V
}


class FsVolumeScheme implements VolumeScheme<SubdirectoryVolume> {
    fs: Volume
    wp: {new(): WatchPolicy}
    constructor(_fs: Volume = <any>fs, wp: {new(): WatchPolicy} = WatchPolicy.Individual) {
        this.fs = _fs;
        this.wp = wp;
    }
    createVolumeFromPath(p: string) {
        return new SubdirectoryVolume(this.fs, p, path.join ? path :  pathShim)
            .withWatchPolicy(new this.wp);
    }
}


export { VolumeFactory, VolumeScheme, FsVolumeScheme }