import type { Volume, WatchPolicy } from '../infra/volume';
import { FsVolumeScheme } from '../infra/volume-factory';
import { PackageManager, Resource, ResourceBundle } from 'basin-shell/src/package-mgr';


class OnDemandFsVolumeScheme extends FsVolumeScheme {
    packageManager: PackageManager

    constructor(_fs?: Volume, wp?: {new(): WatchPolicy}) {
        super(_fs, wp);
        this.packageManager = new PackageManager(<any>this.fs);  /** @oops need mkdirp */
    }

    createVolumeFromPath(p: string) {
        return super.createVolumeFromPath(p);
    }

    async populate() {
        /** @ohno for now, these are baked-in, because volume operations must be synchronous */
        await this.packageManager.install(ASSETS);
    }
}


const ASSETS: ResourceBundle = {
    '/home/': new Resource('/data/toxin-manual.tar'),
    '/': new Resource('/data/examples.tar')
};


export { OnDemandFsVolumeScheme }