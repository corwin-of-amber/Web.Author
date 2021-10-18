
// Uint8Array concat boilerplate
function concat(arrays: Uint8Array[]) {
    let totalLength = arrays.reduce((acc, value) => acc + value.length, 0),
        result = new Uint8Array(totalLength), pos = 0;
    for (let array of arrays) {
        result.set(array, pos);
        pos += array.length;
    }
    return result;
}


export { concat }