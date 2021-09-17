import type { Volume } from '../infra/volume';
import { FsVolumeScheme } from '../infra/volume-factory';
import { PackageManager, Resource, ResourceBundle } from 'basin-shell/src/package-mgr';


class OnDemandFsVolumeScheme extends FsVolumeScheme {
    packageManager: PackageManager

    constructor(_fs?: Volume) {
        super(_fs);
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
    '/proj1/foo.tex': 'bar', 
    '/proj1/main.tex': 'documentclass ... ',
    '/': new Resource('/data/examples.tar')
};


export { OnDemandFsVolumeScheme }