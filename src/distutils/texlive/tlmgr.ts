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

    async collect(pkgs: Set<string>) {
        var pkgIndex = (await this.pkgInfo).packages,
            deps = (pkg: string) => pkgIndex[pkg]?.deps ?? [];
        return [...closure(pkgs, pkg => deps(pkg))]
            .filter(pkg => !pkgIndex[pkg]?.meta);
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
        meta?: boolean
        deps?: string[]
    };

    export const PKG_DB_URI = '/packages/nanotex/data/pkg-info.json';
}


/**
 * Helper function to compute the closure of a set `s`
 * under an operation `tr`.
 */
function closure<T>(s: Set<T>, tr: (t: T) => T[]) {
    var wl = [...s];
    while (wl.length > 0) {
        var u = wl.shift();
        for (let v of tr(u))
            if (!s.has(v)) { s.add(v); wl.push(v); }
    }
    return s;
}


export { Tlmgr }