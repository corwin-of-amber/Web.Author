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

    async populate(assets: {[dir: string]: string}) {
        var bundle: ResourceBundle = Object.fromEntries(
            Object.entries(assets).map(([dir, uri]) =>
                [dir, new Resource(uri)]
            )
        );
        await this.packageManager.install(bundle);
    }
}


export { OnDemandFsVolumeScheme }