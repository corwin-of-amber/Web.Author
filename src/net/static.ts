import type { Volume } from '../infra/volume';
import { FsVolumeScheme } from '../infra/volume-factory';
import { PackageManager, Resource, ResourceBundle } from 'basin-shell/src/package-mgr';


class OnDemandFsVolumeScheme extends FsVolumeScheme {
    constructor(_fs?: Volume) { super(_fs); }

    createVolumeFromPath(p: string) {
        return super.createVolumeFromPath(p);
    }

    async populate() {
        /** @ohno for now, these are baked-in, because volume operations must be synchronous */
        var pm = new PackageManager(<any>this.fs);  /** @oops need mkdirp */
        await pm.install(ASSETS);
    }
}


const ASSETS: ResourceBundle = {
    '/proj1/foo.tex': 'bar', 
    '/proj1/main.tex': 'documentclass ... ',
    '/overleaf-examples/': new Resource('/data/overleaf-examples.tar')
};


export { OnDemandFsVolumeScheme }