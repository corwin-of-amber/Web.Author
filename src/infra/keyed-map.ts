/* abstract */
class KeyedMap<K,V> extends Map<any,V> {
    get(key: K)            { return super.get(this.realKey(key)); }
    set(key: K, value: V)  { return super.set(this.realKey(key), value); }
    delete(key: K)         { return super.delete(this.realKey(key)); }
    has(key: K)            { return super.has(this.realKey(key)); }
    realKey(key: K): any   { return key; }
}

class JSONKeyedMap<K,V> extends KeyedMap<K,V> {
    realKey(key: K) { return JSON.stringify(key); }
    *entries() {
        for (let [k,v] of super.entries())
            yield [JSON.parse(k), v] as [K, V];
    }
}


export { KeyedMap, JSONKeyedMap }