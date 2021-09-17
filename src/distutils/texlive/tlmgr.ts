/**
 * This class mimics some of the functionality of `tlmgr` from TeX Live
 * and offers general package metadata handling.
 */

class Tlmgr {
    pkgInfo: Promise<Tlmgr.PackageStore>

    constructor() {
        this.pkgInfo = this._fetch();
    }

    async getInfo(pkgs: string | string[]) {
        var pkgInfo = await this.pkgInfo;
        if (typeof pkgs === 'string') return pkgInfo[pkgs];
        else
            return Object.fromEntries(pkgs.map(pkg => [pkg, pkgInfo[pkg]]));
    }

    async collect(pkgs: string[]) {
        var pkgInfo = await this.pkgInfo,
            self = (pkg: string) => pkgInfo.packages[pkg]?.isMeta ? [] : [pkg];
        return [].concat(...pkgs.map(pkg =>
            [...self(pkg), ...(pkgInfo.packages[pkg]?.deps ?? [])]
        ));
    }

    async _fetch() {
        return await (await fetch(Tlmgr.PKG_DB_URI)).json();
    }
}

namespace Tlmgr {
    export type PackageStore = {
        packages: {
            [name: string]: PackageInfo
        }
    };

    export type PackageInfo = {
        isMeta?: boolean
        format?: 'tar' | 'tar.xz'
        deps?: string[]
    };

    export const PKG_DB_URI = '/data/distutils/texlive/pkg-info.json';
}


export { Tlmgr }