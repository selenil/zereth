// build/dev/javascript/gleam_stdlib/gleam/bool.mjs
function guard(requirement, consequence, alternative) {
  if (requirement) {
    return consequence;
  } else {
    return alternative();
  }
}

// build/dev/javascript/prelude.mjs
var CustomType = class {
  withFields(fields) {
    let properties = Object.keys(this).map(
      (label) => label in fields ? fields[label] : this[label]
    );
    return new this.constructor(...properties);
  }
};
var List = class {
  static fromArray(array3, tail) {
    let t = tail || new Empty();
    for (let i = array3.length - 1; i >= 0; --i) {
      t = new NonEmpty(array3[i], t);
    }
    return t;
  }
  [Symbol.iterator]() {
    return new ListIterator(this);
  }
  toArray() {
    return [...this];
  }
  // @internal
  atLeastLength(desired) {
    let current = this;
    while (desired-- > 0 && current)
      current = current.tail;
    return current !== void 0;
  }
  // @internal
  hasLength(desired) {
    let current = this;
    while (desired-- > 0 && current)
      current = current.tail;
    return desired === -1 && current instanceof Empty;
  }
  // @internal
  countLength() {
    let current = this;
    let length3 = 0;
    while (current) {
      current = current.tail;
      length3++;
    }
    return length3 - 1;
  }
};
function prepend(element2, tail) {
  return new NonEmpty(element2, tail);
}
function toList(elements2, tail) {
  return List.fromArray(elements2, tail);
}
var ListIterator = class {
  #current;
  constructor(current) {
    this.#current = current;
  }
  next() {
    if (this.#current instanceof Empty) {
      return { done: true };
    } else {
      let { head, tail } = this.#current;
      this.#current = tail;
      return { value: head, done: false };
    }
  }
};
var Empty = class extends List {
};
var NonEmpty = class extends List {
  constructor(head, tail) {
    super();
    this.head = head;
    this.tail = tail;
  }
};
var BitArray = class {
  /**
   * The size in bits of this bit array's data.
   *
   * @type {number}
   */
  bitSize;
  /**
   * The size in bytes of this bit array's data. If this bit array doesn't store
   * a whole number of bytes then this value is rounded up.
   *
   * @type {number}
   */
  byteSize;
  /**
   * The number of unused high bits in the first byte of this bit array's
   * buffer prior to the start of its data. The value of any unused high bits is
   * undefined.
   *
   * The bit offset will be in the range 0-7.
   *
   * @type {number}
   */
  bitOffset;
  /**
   * The raw bytes that hold this bit array's data.
   *
   * If `bitOffset` is not zero then there are unused high bits in the first
   * byte of this buffer.
   *
   * If `bitOffset + bitSize` is not a multiple of 8 then there are unused low
   * bits in the last byte of this buffer.
   *
   * @type {Uint8Array}
   */
  rawBuffer;
  /**
   * Constructs a new bit array from a `Uint8Array`, an optional size in
   * bits, and an optional bit offset.
   *
   * If no bit size is specified it is taken as `buffer.length * 8`, i.e. all
   * bytes in the buffer make up the new bit array's data.
   *
   * If no bit offset is specified it defaults to zero, i.e. there are no unused
   * high bits in the first byte of the buffer.
   *
   * @param {Uint8Array} buffer
   * @param {number} [bitSize]
   * @param {number} [bitOffset]
   */
  constructor(buffer, bitSize, bitOffset) {
    if (!(buffer instanceof Uint8Array)) {
      throw globalThis.Error(
        "BitArray can only be constructed from a Uint8Array"
      );
    }
    this.bitSize = bitSize ?? buffer.length * 8;
    this.byteSize = Math.trunc((this.bitSize + 7) / 8);
    this.bitOffset = bitOffset ?? 0;
    if (this.bitSize < 0) {
      throw globalThis.Error(`BitArray bit size is invalid: ${this.bitSize}`);
    }
    if (this.bitOffset < 0 || this.bitOffset > 7) {
      throw globalThis.Error(
        `BitArray bit offset is invalid: ${this.bitOffset}`
      );
    }
    if (buffer.length !== Math.trunc((this.bitOffset + this.bitSize + 7) / 8)) {
      throw globalThis.Error("BitArray buffer length is invalid");
    }
    this.rawBuffer = buffer;
  }
  /**
   * Returns a specific byte in this bit array. If the byte index is out of
   * range then `undefined` is returned.
   *
   * When returning the final byte of a bit array with a bit size that's not a
   * multiple of 8, the content of the unused low bits are undefined.
   *
   * @param {number} index
   * @returns {number | undefined}
   */
  byteAt(index3) {
    if (index3 < 0 || index3 >= this.byteSize) {
      return void 0;
    }
    return bitArrayByteAt(this.rawBuffer, this.bitOffset, index3);
  }
  /** @internal */
  equals(other) {
    if (this.bitSize !== other.bitSize) {
      return false;
    }
    const wholeByteCount = Math.trunc(this.bitSize / 8);
    if (this.bitOffset === 0 && other.bitOffset === 0) {
      for (let i = 0; i < wholeByteCount; i++) {
        if (this.rawBuffer[i] !== other.rawBuffer[i]) {
          return false;
        }
      }
      const trailingBitsCount = this.bitSize % 8;
      if (trailingBitsCount) {
        const unusedLowBitCount = 8 - trailingBitsCount;
        if (this.rawBuffer[wholeByteCount] >> unusedLowBitCount !== other.rawBuffer[wholeByteCount] >> unusedLowBitCount) {
          return false;
        }
      }
    } else {
      for (let i = 0; i < wholeByteCount; i++) {
        const a = bitArrayByteAt(this.rawBuffer, this.bitOffset, i);
        const b = bitArrayByteAt(other.rawBuffer, other.bitOffset, i);
        if (a !== b) {
          return false;
        }
      }
      const trailingBitsCount = this.bitSize % 8;
      if (trailingBitsCount) {
        const a = bitArrayByteAt(
          this.rawBuffer,
          this.bitOffset,
          wholeByteCount
        );
        const b = bitArrayByteAt(
          other.rawBuffer,
          other.bitOffset,
          wholeByteCount
        );
        const unusedLowBitCount = 8 - trailingBitsCount;
        if (a >> unusedLowBitCount !== b >> unusedLowBitCount) {
          return false;
        }
      }
    }
    return true;
  }
  /**
   * Returns this bit array's internal buffer.
   *
   * @deprecated Use `BitArray.byteAt()` or `BitArray.rawBuffer` instead.
   *
   * @returns {Uint8Array}
   */
  get buffer() {
    bitArrayPrintDeprecationWarning(
      "buffer",
      "Use BitArray.byteAt() or BitArray.rawBuffer instead"
    );
    if (this.bitOffset !== 0 || this.bitSize % 8 !== 0) {
      throw new globalThis.Error(
        "BitArray.buffer does not support unaligned bit arrays"
      );
    }
    return this.rawBuffer;
  }
  /**
   * Returns the length in bytes of this bit array's internal buffer.
   *
   * @deprecated Use `BitArray.bitSize` or `BitArray.byteSize` instead.
   *
   * @returns {number}
   */
  get length() {
    bitArrayPrintDeprecationWarning(
      "length",
      "Use BitArray.bitSize or BitArray.byteSize instead"
    );
    if (this.bitOffset !== 0 || this.bitSize % 8 !== 0) {
      throw new globalThis.Error(
        "BitArray.length does not support unaligned bit arrays"
      );
    }
    return this.rawBuffer.length;
  }
};
function bitArrayByteAt(buffer, bitOffset, index3) {
  if (bitOffset === 0) {
    return buffer[index3] ?? 0;
  } else {
    const a = buffer[index3] << bitOffset & 255;
    const b = buffer[index3 + 1] >> 8 - bitOffset;
    return a | b;
  }
}
var isBitArrayDeprecationMessagePrinted = {};
function bitArrayPrintDeprecationWarning(name, message) {
  if (isBitArrayDeprecationMessagePrinted[name]) {
    return;
  }
  console.warn(
    `Deprecated BitArray.${name} property used in JavaScript FFI code. ${message}.`
  );
  isBitArrayDeprecationMessagePrinted[name] = true;
}
var Result = class _Result extends CustomType {
  // @internal
  static isResult(data) {
    return data instanceof _Result;
  }
};
var Ok = class extends Result {
  constructor(value) {
    super();
    this[0] = value;
  }
  // @internal
  isOk() {
    return true;
  }
};
var Error = class extends Result {
  constructor(detail) {
    super();
    this[0] = detail;
  }
  // @internal
  isOk() {
    return false;
  }
};
function isEqual(x, y) {
  let values2 = [x, y];
  while (values2.length) {
    let a = values2.pop();
    let b = values2.pop();
    if (a === b)
      continue;
    if (!isObject(a) || !isObject(b))
      return false;
    let unequal = !structurallyCompatibleObjects(a, b) || unequalDates(a, b) || unequalBuffers(a, b) || unequalArrays(a, b) || unequalMaps(a, b) || unequalSets(a, b) || unequalRegExps(a, b);
    if (unequal)
      return false;
    const proto = Object.getPrototypeOf(a);
    if (proto !== null && typeof proto.equals === "function") {
      try {
        if (a.equals(b))
          continue;
        else
          return false;
      } catch {
      }
    }
    let [keys2, get] = getters(a);
    for (let k of keys2(a)) {
      values2.push(get(a, k), get(b, k));
    }
  }
  return true;
}
function getters(object3) {
  if (object3 instanceof Map) {
    return [(x) => x.keys(), (x, y) => x.get(y)];
  } else {
    let extra = object3 instanceof globalThis.Error ? ["message"] : [];
    return [(x) => [...extra, ...Object.keys(x)], (x, y) => x[y]];
  }
}
function unequalDates(a, b) {
  return a instanceof Date && (a > b || a < b);
}
function unequalBuffers(a, b) {
  return !(a instanceof BitArray) && a.buffer instanceof ArrayBuffer && a.BYTES_PER_ELEMENT && !(a.byteLength === b.byteLength && a.every((n, i) => n === b[i]));
}
function unequalArrays(a, b) {
  return Array.isArray(a) && a.length !== b.length;
}
function unequalMaps(a, b) {
  return a instanceof Map && a.size !== b.size;
}
function unequalSets(a, b) {
  return a instanceof Set && (a.size != b.size || [...a].some((e) => !b.has(e)));
}
function unequalRegExps(a, b) {
  return a instanceof RegExp && (a.source !== b.source || a.flags !== b.flags);
}
function isObject(a) {
  return typeof a === "object" && a !== null;
}
function structurallyCompatibleObjects(a, b) {
  if (typeof a !== "object" && typeof b !== "object" && (!a || !b))
    return false;
  let nonstructural = [Promise, WeakSet, WeakMap, Function];
  if (nonstructural.some((c) => a instanceof c))
    return false;
  return a.constructor === b.constructor;
}
function makeError(variant, module, line, fn, message, extra) {
  let error = new globalThis.Error(message);
  error.gleam_error = variant;
  error.module = module;
  error.line = line;
  error.function = fn;
  error.fn = fn;
  for (let k in extra)
    error[k] = extra[k];
  return error;
}

// build/dev/javascript/gleam_stdlib/gleam/order.mjs
var Lt = class extends CustomType {
};
var Eq = class extends CustomType {
};
var Gt = class extends CustomType {
};

// build/dev/javascript/gleam_stdlib/gleam/option.mjs
var Some = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var None = class extends CustomType {
};

// build/dev/javascript/gleam_stdlib/dict.mjs
var referenceMap = /* @__PURE__ */ new WeakMap();
var tempDataView = new DataView(new ArrayBuffer(8));
var referenceUID = 0;
function hashByReference(o) {
  const known = referenceMap.get(o);
  if (known !== void 0) {
    return known;
  }
  const hash = referenceUID++;
  if (referenceUID === 2147483647) {
    referenceUID = 0;
  }
  referenceMap.set(o, hash);
  return hash;
}
function hashMerge(a, b) {
  return a ^ b + 2654435769 + (a << 6) + (a >> 2) | 0;
}
function hashString(s) {
  let hash = 0;
  const len = s.length;
  for (let i = 0; i < len; i++) {
    hash = Math.imul(31, hash) + s.charCodeAt(i) | 0;
  }
  return hash;
}
function hashNumber(n) {
  tempDataView.setFloat64(0, n);
  const i = tempDataView.getInt32(0);
  const j = tempDataView.getInt32(4);
  return Math.imul(73244475, i >> 16 ^ i) ^ j;
}
function hashBigInt(n) {
  return hashString(n.toString());
}
function hashObject(o) {
  const proto = Object.getPrototypeOf(o);
  if (proto !== null && typeof proto.hashCode === "function") {
    try {
      const code = o.hashCode(o);
      if (typeof code === "number") {
        return code;
      }
    } catch {
    }
  }
  if (o instanceof Promise || o instanceof WeakSet || o instanceof WeakMap) {
    return hashByReference(o);
  }
  if (o instanceof Date) {
    return hashNumber(o.getTime());
  }
  let h = 0;
  if (o instanceof ArrayBuffer) {
    o = new Uint8Array(o);
  }
  if (Array.isArray(o) || o instanceof Uint8Array) {
    for (let i = 0; i < o.length; i++) {
      h = Math.imul(31, h) + getHash(o[i]) | 0;
    }
  } else if (o instanceof Set) {
    o.forEach((v) => {
      h = h + getHash(v) | 0;
    });
  } else if (o instanceof Map) {
    o.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
  } else {
    const keys2 = Object.keys(o);
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      const v = o[k];
      h = h + hashMerge(getHash(v), hashString(k)) | 0;
    }
  }
  return h;
}
function getHash(u) {
  if (u === null)
    return 1108378658;
  if (u === void 0)
    return 1108378659;
  if (u === true)
    return 1108378657;
  if (u === false)
    return 1108378656;
  switch (typeof u) {
    case "number":
      return hashNumber(u);
    case "string":
      return hashString(u);
    case "bigint":
      return hashBigInt(u);
    case "object":
      return hashObject(u);
    case "symbol":
      return hashByReference(u);
    case "function":
      return hashByReference(u);
    default:
      return 0;
  }
}
var SHIFT = 5;
var BUCKET_SIZE = Math.pow(2, SHIFT);
var MASK = BUCKET_SIZE - 1;
var MAX_INDEX_NODE = BUCKET_SIZE / 2;
var MIN_ARRAY_NODE = BUCKET_SIZE / 4;
var ENTRY = 0;
var ARRAY_NODE = 1;
var INDEX_NODE = 2;
var COLLISION_NODE = 3;
var EMPTY = {
  type: INDEX_NODE,
  bitmap: 0,
  array: []
};
function mask(hash, shift) {
  return hash >>> shift & MASK;
}
function bitpos(hash, shift) {
  return 1 << mask(hash, shift);
}
function bitcount(x) {
  x -= x >> 1 & 1431655765;
  x = (x & 858993459) + (x >> 2 & 858993459);
  x = x + (x >> 4) & 252645135;
  x += x >> 8;
  x += x >> 16;
  return x & 127;
}
function index(bitmap, bit) {
  return bitcount(bitmap & bit - 1);
}
function cloneAndSet(arr, at, val) {
  const len = arr.length;
  const out = new Array(len);
  for (let i = 0; i < len; ++i) {
    out[i] = arr[i];
  }
  out[at] = val;
  return out;
}
function spliceIn(arr, at, val) {
  const len = arr.length;
  const out = new Array(len + 1);
  let i = 0;
  let g = 0;
  while (i < at) {
    out[g++] = arr[i++];
  }
  out[g++] = val;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function spliceOut(arr, at) {
  const len = arr.length;
  const out = new Array(len - 1);
  let i = 0;
  let g = 0;
  while (i < at) {
    out[g++] = arr[i++];
  }
  ++i;
  while (i < len) {
    out[g++] = arr[i++];
  }
  return out;
}
function createNode(shift, key1, val1, key2hash, key2, val2) {
  const key1hash = getHash(key1);
  if (key1hash === key2hash) {
    return {
      type: COLLISION_NODE,
      hash: key1hash,
      array: [
        { type: ENTRY, k: key1, v: val1 },
        { type: ENTRY, k: key2, v: val2 }
      ]
    };
  }
  const addedLeaf = { val: false };
  return assoc(
    assocIndex(EMPTY, shift, key1hash, key1, val1, addedLeaf),
    shift,
    key2hash,
    key2,
    val2,
    addedLeaf
  );
}
function assoc(root, shift, hash, key, val, addedLeaf) {
  switch (root.type) {
    case ARRAY_NODE:
      return assocArray(root, shift, hash, key, val, addedLeaf);
    case INDEX_NODE:
      return assocIndex(root, shift, hash, key, val, addedLeaf);
    case COLLISION_NODE:
      return assocCollision(root, shift, hash, key, val, addedLeaf);
  }
}
function assocArray(root, shift, hash, key, val, addedLeaf) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root.size + 1,
      array: cloneAndSet(root.array, idx, { type: ENTRY, k: key, v: val })
    };
  }
  if (node.type === ENTRY) {
    if (isEqual(key, node.k)) {
      if (val === node.v) {
        return root;
      }
      return {
        type: ARRAY_NODE,
        size: root.size,
        array: cloneAndSet(root.array, idx, {
          type: ENTRY,
          k: key,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: ARRAY_NODE,
      size: root.size,
      array: cloneAndSet(
        root.array,
        idx,
        createNode(shift + SHIFT, node.k, node.v, hash, key, val)
      )
    };
  }
  const n = assoc(node, shift + SHIFT, hash, key, val, addedLeaf);
  if (n === node) {
    return root;
  }
  return {
    type: ARRAY_NODE,
    size: root.size,
    array: cloneAndSet(root.array, idx, n)
  };
}
function assocIndex(root, shift, hash, key, val, addedLeaf) {
  const bit = bitpos(hash, shift);
  const idx = index(root.bitmap, bit);
  if ((root.bitmap & bit) !== 0) {
    const node = root.array[idx];
    if (node.type !== ENTRY) {
      const n = assoc(node, shift + SHIFT, hash, key, val, addedLeaf);
      if (n === node) {
        return root;
      }
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, n)
      };
    }
    const nodeKey = node.k;
    if (isEqual(key, nodeKey)) {
      if (val === node.v) {
        return root;
      }
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, {
          type: ENTRY,
          k: key,
          v: val
        })
      };
    }
    addedLeaf.val = true;
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap,
      array: cloneAndSet(
        root.array,
        idx,
        createNode(shift + SHIFT, nodeKey, node.v, hash, key, val)
      )
    };
  } else {
    const n = root.array.length;
    if (n >= MAX_INDEX_NODE) {
      const nodes = new Array(32);
      const jdx = mask(hash, shift);
      nodes[jdx] = assocIndex(EMPTY, shift + SHIFT, hash, key, val, addedLeaf);
      let j = 0;
      let bitmap = root.bitmap;
      for (let i = 0; i < 32; i++) {
        if ((bitmap & 1) !== 0) {
          const node = root.array[j++];
          nodes[i] = node;
        }
        bitmap = bitmap >>> 1;
      }
      return {
        type: ARRAY_NODE,
        size: n + 1,
        array: nodes
      };
    } else {
      const newArray = spliceIn(root.array, idx, {
        type: ENTRY,
        k: key,
        v: val
      });
      addedLeaf.val = true;
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap | bit,
        array: newArray
      };
    }
  }
}
function assocCollision(root, shift, hash, key, val, addedLeaf) {
  if (hash === root.hash) {
    const idx = collisionIndexOf(root, key);
    if (idx !== -1) {
      const entry = root.array[idx];
      if (entry.v === val) {
        return root;
      }
      return {
        type: COLLISION_NODE,
        hash,
        array: cloneAndSet(root.array, idx, { type: ENTRY, k: key, v: val })
      };
    }
    const size = root.array.length;
    addedLeaf.val = true;
    return {
      type: COLLISION_NODE,
      hash,
      array: cloneAndSet(root.array, size, { type: ENTRY, k: key, v: val })
    };
  }
  return assoc(
    {
      type: INDEX_NODE,
      bitmap: bitpos(root.hash, shift),
      array: [root]
    },
    shift,
    hash,
    key,
    val,
    addedLeaf
  );
}
function collisionIndexOf(root, key) {
  const size = root.array.length;
  for (let i = 0; i < size; i++) {
    if (isEqual(key, root.array[i].k)) {
      return i;
    }
  }
  return -1;
}
function find(root, shift, hash, key) {
  switch (root.type) {
    case ARRAY_NODE:
      return findArray(root, shift, hash, key);
    case INDEX_NODE:
      return findIndex(root, shift, hash, key);
    case COLLISION_NODE:
      return findCollision(root, key);
  }
}
function findArray(root, shift, hash, key) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    return void 0;
  }
  if (node.type !== ENTRY) {
    return find(node, shift + SHIFT, hash, key);
  }
  if (isEqual(key, node.k)) {
    return node;
  }
  return void 0;
}
function findIndex(root, shift, hash, key) {
  const bit = bitpos(hash, shift);
  if ((root.bitmap & bit) === 0) {
    return void 0;
  }
  const idx = index(root.bitmap, bit);
  const node = root.array[idx];
  if (node.type !== ENTRY) {
    return find(node, shift + SHIFT, hash, key);
  }
  if (isEqual(key, node.k)) {
    return node;
  }
  return void 0;
}
function findCollision(root, key) {
  const idx = collisionIndexOf(root, key);
  if (idx < 0) {
    return void 0;
  }
  return root.array[idx];
}
function without(root, shift, hash, key) {
  switch (root.type) {
    case ARRAY_NODE:
      return withoutArray(root, shift, hash, key);
    case INDEX_NODE:
      return withoutIndex(root, shift, hash, key);
    case COLLISION_NODE:
      return withoutCollision(root, key);
  }
}
function withoutArray(root, shift, hash, key) {
  const idx = mask(hash, shift);
  const node = root.array[idx];
  if (node === void 0) {
    return root;
  }
  let n = void 0;
  if (node.type === ENTRY) {
    if (!isEqual(node.k, key)) {
      return root;
    }
  } else {
    n = without(node, shift + SHIFT, hash, key);
    if (n === node) {
      return root;
    }
  }
  if (n === void 0) {
    if (root.size <= MIN_ARRAY_NODE) {
      const arr = root.array;
      const out = new Array(root.size - 1);
      let i = 0;
      let j = 0;
      let bitmap = 0;
      while (i < idx) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      ++i;
      while (i < arr.length) {
        const nv = arr[i];
        if (nv !== void 0) {
          out[j] = nv;
          bitmap |= 1 << i;
          ++j;
        }
        ++i;
      }
      return {
        type: INDEX_NODE,
        bitmap,
        array: out
      };
    }
    return {
      type: ARRAY_NODE,
      size: root.size - 1,
      array: cloneAndSet(root.array, idx, n)
    };
  }
  return {
    type: ARRAY_NODE,
    size: root.size,
    array: cloneAndSet(root.array, idx, n)
  };
}
function withoutIndex(root, shift, hash, key) {
  const bit = bitpos(hash, shift);
  if ((root.bitmap & bit) === 0) {
    return root;
  }
  const idx = index(root.bitmap, bit);
  const node = root.array[idx];
  if (node.type !== ENTRY) {
    const n = without(node, shift + SHIFT, hash, key);
    if (n === node) {
      return root;
    }
    if (n !== void 0) {
      return {
        type: INDEX_NODE,
        bitmap: root.bitmap,
        array: cloneAndSet(root.array, idx, n)
      };
    }
    if (root.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap ^ bit,
      array: spliceOut(root.array, idx)
    };
  }
  if (isEqual(key, node.k)) {
    if (root.bitmap === bit) {
      return void 0;
    }
    return {
      type: INDEX_NODE,
      bitmap: root.bitmap ^ bit,
      array: spliceOut(root.array, idx)
    };
  }
  return root;
}
function withoutCollision(root, key) {
  const idx = collisionIndexOf(root, key);
  if (idx < 0) {
    return root;
  }
  if (root.array.length === 1) {
    return void 0;
  }
  return {
    type: COLLISION_NODE,
    hash: root.hash,
    array: spliceOut(root.array, idx)
  };
}
function forEach(root, fn) {
  if (root === void 0) {
    return;
  }
  const items = root.array;
  const size = items.length;
  for (let i = 0; i < size; i++) {
    const item = items[i];
    if (item === void 0) {
      continue;
    }
    if (item.type === ENTRY) {
      fn(item.v, item.k);
      continue;
    }
    forEach(item, fn);
  }
}
var Dict = class _Dict {
  /**
   * @template V
   * @param {Record<string,V>} o
   * @returns {Dict<string,V>}
   */
  static fromObject(o) {
    const keys2 = Object.keys(o);
    let m = _Dict.new();
    for (let i = 0; i < keys2.length; i++) {
      const k = keys2[i];
      m = m.set(k, o[k]);
    }
    return m;
  }
  /**
   * @template K,V
   * @param {Map<K,V>} o
   * @returns {Dict<K,V>}
   */
  static fromMap(o) {
    let m = _Dict.new();
    o.forEach((v, k) => {
      m = m.set(k, v);
    });
    return m;
  }
  static new() {
    return new _Dict(void 0, 0);
  }
  /**
   * @param {undefined | Node<K,V>} root
   * @param {number} size
   */
  constructor(root, size) {
    this.root = root;
    this.size = size;
  }
  /**
   * @template NotFound
   * @param {K} key
   * @param {NotFound} notFound
   * @returns {NotFound | V}
   */
  get(key, notFound) {
    if (this.root === void 0) {
      return notFound;
    }
    const found = find(this.root, 0, getHash(key), key);
    if (found === void 0) {
      return notFound;
    }
    return found.v;
  }
  /**
   * @param {K} key
   * @param {V} val
   * @returns {Dict<K,V>}
   */
  set(key, val) {
    const addedLeaf = { val: false };
    const root = this.root === void 0 ? EMPTY : this.root;
    const newRoot = assoc(root, 0, getHash(key), key, val, addedLeaf);
    if (newRoot === this.root) {
      return this;
    }
    return new _Dict(newRoot, addedLeaf.val ? this.size + 1 : this.size);
  }
  /**
   * @param {K} key
   * @returns {Dict<K,V>}
   */
  delete(key) {
    if (this.root === void 0) {
      return this;
    }
    const newRoot = without(this.root, 0, getHash(key), key);
    if (newRoot === this.root) {
      return this;
    }
    if (newRoot === void 0) {
      return _Dict.new();
    }
    return new _Dict(newRoot, this.size - 1);
  }
  /**
   * @param {K} key
   * @returns {boolean}
   */
  has(key) {
    if (this.root === void 0) {
      return false;
    }
    return find(this.root, 0, getHash(key), key) !== void 0;
  }
  /**
   * @returns {[K,V][]}
   */
  entries() {
    if (this.root === void 0) {
      return [];
    }
    const result = [];
    this.forEach((v, k) => result.push([k, v]));
    return result;
  }
  /**
   *
   * @param {(val:V,key:K)=>void} fn
   */
  forEach(fn) {
    forEach(this.root, fn);
  }
  hashCode() {
    let h = 0;
    this.forEach((v, k) => {
      h = h + hashMerge(getHash(v), getHash(k)) | 0;
    });
    return h;
  }
  /**
   * @param {unknown} o
   * @returns {boolean}
   */
  equals(o) {
    if (!(o instanceof _Dict) || this.size !== o.size) {
      return false;
    }
    try {
      this.forEach((v, k) => {
        if (!isEqual(o.get(k, !v), v)) {
          throw unequalDictSymbol;
        }
      });
      return true;
    } catch (e) {
      if (e === unequalDictSymbol) {
        return false;
      }
      throw e;
    }
  }
};
var unequalDictSymbol = Symbol();

// build/dev/javascript/gleam_stdlib/gleam_stdlib.mjs
var Nil = void 0;
var NOT_FOUND = {};
function identity(x) {
  return x;
}
function to_string(term) {
  return term.toString();
}
var segmenter = void 0;
function graphemes_iterator(string4) {
  if (globalThis.Intl && Intl.Segmenter) {
    segmenter ||= new Intl.Segmenter();
    return segmenter.segment(string4)[Symbol.iterator]();
  }
}
function pop_grapheme(string4) {
  let first3;
  const iterator = graphemes_iterator(string4);
  if (iterator) {
    first3 = iterator.next().value?.segment;
  } else {
    first3 = string4.match(/./su)?.[0];
  }
  if (first3) {
    return new Ok([first3, string4.slice(first3.length)]);
  } else {
    return new Error(Nil);
  }
}
var unicode_whitespaces = [
  " ",
  // Space
  "	",
  // Horizontal tab
  "\n",
  // Line feed
  "\v",
  // Vertical tab
  "\f",
  // Form feed
  "\r",
  // Carriage return
  "\x85",
  // Next line
  "\u2028",
  // Line separator
  "\u2029"
  // Paragraph separator
].join("");
var trim_start_regex = new RegExp(`^[${unicode_whitespaces}]*`);
var trim_end_regex = new RegExp(`[${unicode_whitespaces}]*$`);
function console_log(term) {
  console.log(term);
}
function console_error(term) {
  console.error(term);
}
function new_map() {
  return Dict.new();
}
function map_to_list(map4) {
  return List.fromArray(map4.entries());
}
function map_get(map4, key) {
  const value = map4.get(key, NOT_FOUND);
  if (value === NOT_FOUND) {
    return new Error(Nil);
  }
  return new Ok(value);
}
function map_insert(key, value, map4) {
  return map4.set(key, value);
}

// build/dev/javascript/gleam_stdlib/gleam/int.mjs
function absolute_value(x) {
  let $ = x >= 0;
  if ($) {
    return x;
  } else {
    return x * -1;
  }
}
function compare(a, b) {
  let $ = a === b;
  if ($) {
    return new Eq();
  } else {
    let $1 = a < b;
    if ($1) {
      return new Lt();
    } else {
      return new Gt();
    }
  }
}

// build/dev/javascript/gleam_stdlib/gleam/dict.mjs
function insert(dict2, key, value) {
  return map_insert(key, value, dict2);
}
function reverse_and_concat(loop$remaining, loop$accumulator) {
  while (true) {
    let remaining = loop$remaining;
    let accumulator = loop$accumulator;
    if (remaining.hasLength(0)) {
      return accumulator;
    } else {
      let item = remaining.head;
      let rest = remaining.tail;
      loop$remaining = rest;
      loop$accumulator = prepend(item, accumulator);
    }
  }
}
function do_keys_loop(loop$list, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let acc = loop$acc;
    if (list2.hasLength(0)) {
      return reverse_and_concat(acc, toList([]));
    } else {
      let first3 = list2.head;
      let rest = list2.tail;
      loop$list = rest;
      loop$acc = prepend(first3[0], acc);
    }
  }
}
function keys(dict2) {
  let list_of_pairs = map_to_list(dict2);
  return do_keys_loop(list_of_pairs, toList([]));
}

// build/dev/javascript/gleam_stdlib/gleam/list.mjs
function length_loop(loop$list, loop$count) {
  while (true) {
    let list2 = loop$list;
    let count = loop$count;
    if (list2.atLeastLength(1)) {
      let list$1 = list2.tail;
      loop$list = list$1;
      loop$count = count + 1;
    } else {
      return count;
    }
  }
}
function length(list2) {
  return length_loop(list2, 0);
}
function reverse_loop(loop$remaining, loop$accumulator) {
  while (true) {
    let remaining = loop$remaining;
    let accumulator = loop$accumulator;
    if (remaining.hasLength(0)) {
      return accumulator;
    } else {
      let item = remaining.head;
      let rest$1 = remaining.tail;
      loop$remaining = rest$1;
      loop$accumulator = prepend(item, accumulator);
    }
  }
}
function reverse(list2) {
  return reverse_loop(list2, toList([]));
}
function is_empty(list2) {
  return isEqual(list2, toList([]));
}
function contains(loop$list, loop$elem) {
  while (true) {
    let list2 = loop$list;
    let elem = loop$elem;
    if (list2.hasLength(0)) {
      return false;
    } else if (list2.atLeastLength(1) && isEqual(list2.head, elem)) {
      let first$1 = list2.head;
      return true;
    } else {
      let rest$1 = list2.tail;
      loop$list = rest$1;
      loop$elem = elem;
    }
  }
}
function first(list2) {
  if (list2.hasLength(0)) {
    return new Error(void 0);
  } else {
    let x = list2.head;
    return new Ok(x);
  }
}
function filter_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list2.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list2.head;
      let rest$1 = list2.tail;
      let _block;
      let $ = fun(first$1);
      if ($) {
        _block = prepend(first$1, acc);
      } else {
        _block = acc;
      }
      let new_acc = _block;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}
function filter(list2, predicate) {
  return filter_loop(list2, predicate, toList([]));
}
function filter_map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list2.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list2.head;
      let rest$1 = list2.tail;
      let _block;
      let $ = fun(first$1);
      if ($.isOk()) {
        let first$2 = $[0];
        _block = prepend(first$2, acc);
      } else {
        _block = acc;
      }
      let new_acc = _block;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = new_acc;
    }
  }
}
function filter_map(list2, fun) {
  return filter_map_loop(list2, fun, toList([]));
}
function map_loop(loop$list, loop$fun, loop$acc) {
  while (true) {
    let list2 = loop$list;
    let fun = loop$fun;
    let acc = loop$acc;
    if (list2.hasLength(0)) {
      return reverse(acc);
    } else {
      let first$1 = list2.head;
      let rest$1 = list2.tail;
      loop$list = rest$1;
      loop$fun = fun;
      loop$acc = prepend(fun(first$1), acc);
    }
  }
}
function map(list2, fun) {
  return map_loop(list2, fun, toList([]));
}
function reverse_and_prepend(loop$prefix, loop$suffix) {
  while (true) {
    let prefix = loop$prefix;
    let suffix = loop$suffix;
    if (prefix.hasLength(0)) {
      return suffix;
    } else {
      let first$1 = prefix.head;
      let rest$1 = prefix.tail;
      loop$prefix = rest$1;
      loop$suffix = prepend(first$1, suffix);
    }
  }
}
function flatten_loop(loop$lists, loop$acc) {
  while (true) {
    let lists = loop$lists;
    let acc = loop$acc;
    if (lists.hasLength(0)) {
      return reverse(acc);
    } else {
      let list2 = lists.head;
      let further_lists = lists.tail;
      loop$lists = further_lists;
      loop$acc = reverse_and_prepend(list2, acc);
    }
  }
}
function flatten(lists) {
  return flatten_loop(lists, toList([]));
}
function flat_map(list2, fun) {
  let _pipe = map(list2, fun);
  return flatten(_pipe);
}
function fold(loop$list, loop$initial, loop$fun) {
  while (true) {
    let list2 = loop$list;
    let initial = loop$initial;
    let fun = loop$fun;
    if (list2.hasLength(0)) {
      return initial;
    } else {
      let x = list2.head;
      let rest$1 = list2.tail;
      loop$list = rest$1;
      loop$initial = fun(initial, x);
      loop$fun = fun;
    }
  }
}
function index_fold_loop(loop$over, loop$acc, loop$with, loop$index) {
  while (true) {
    let over = loop$over;
    let acc = loop$acc;
    let with$ = loop$with;
    let index3 = loop$index;
    if (over.hasLength(0)) {
      return acc;
    } else {
      let first$1 = over.head;
      let rest$1 = over.tail;
      loop$over = rest$1;
      loop$acc = with$(acc, first$1, index3);
      loop$with = with$;
      loop$index = index3 + 1;
    }
  }
}
function index_fold(list2, initial, fun) {
  return index_fold_loop(list2, initial, fun, 0);
}
function find2(loop$list, loop$is_desired) {
  while (true) {
    let list2 = loop$list;
    let is_desired = loop$is_desired;
    if (list2.hasLength(0)) {
      return new Error(void 0);
    } else {
      let x = list2.head;
      let rest$1 = list2.tail;
      let $ = is_desired(x);
      if ($) {
        return new Ok(x);
      } else {
        loop$list = rest$1;
        loop$is_desired = is_desired;
      }
    }
  }
}
function all(loop$list, loop$predicate) {
  while (true) {
    let list2 = loop$list;
    let predicate = loop$predicate;
    if (list2.hasLength(0)) {
      return true;
    } else {
      let first$1 = list2.head;
      let rest$1 = list2.tail;
      let $ = predicate(first$1);
      if ($) {
        loop$list = rest$1;
        loop$predicate = predicate;
      } else {
        return false;
      }
    }
  }
}
function any(loop$list, loop$predicate) {
  while (true) {
    let list2 = loop$list;
    let predicate = loop$predicate;
    if (list2.hasLength(0)) {
      return false;
    } else {
      let first$1 = list2.head;
      let rest$1 = list2.tail;
      let $ = predicate(first$1);
      if ($) {
        return true;
      } else {
        loop$list = rest$1;
        loop$predicate = predicate;
      }
    }
  }
}
function range_loop(loop$start, loop$stop, loop$acc) {
  while (true) {
    let start3 = loop$start;
    let stop = loop$stop;
    let acc = loop$acc;
    let $ = compare(start3, stop);
    if ($ instanceof Eq) {
      return prepend(stop, acc);
    } else if ($ instanceof Gt) {
      loop$start = start3;
      loop$stop = stop + 1;
      loop$acc = prepend(stop, acc);
    } else {
      loop$start = start3;
      loop$stop = stop - 1;
      loop$acc = prepend(stop, acc);
    }
  }
}
function range(start3, stop) {
  return range_loop(start3, stop, toList([]));
}

// build/dev/javascript/gleam_stdlib/gleam/string.mjs
function drop_start(loop$string, loop$num_graphemes) {
  while (true) {
    let string4 = loop$string;
    let num_graphemes = loop$num_graphemes;
    let $ = num_graphemes > 0;
    if (!$) {
      return string4;
    } else {
      let $1 = pop_grapheme(string4);
      if ($1.isOk()) {
        let string$1 = $1[0][1];
        loop$string = string$1;
        loop$num_graphemes = num_graphemes - 1;
      } else {
        return string4;
      }
    }
  }
}

// build/dev/javascript/gleam_stdlib/gleam/result.mjs
function is_ok(result) {
  if (!result.isOk()) {
    return false;
  } else {
    return true;
  }
}

// build/dev/javascript/lustre/lustre/effect.mjs
var Effect = class extends CustomType {
  constructor(all2) {
    super();
    this.all = all2;
  }
};
function none() {
  return new Effect(toList([]));
}

// build/dev/javascript/lustre/lustre/internals/vdom.mjs
var Text = class extends CustomType {
  constructor(content) {
    super();
    this.content = content;
  }
};
var Element = class extends CustomType {
  constructor(key, namespace, tag, attrs, children2, self_closing, void$) {
    super();
    this.key = key;
    this.namespace = namespace;
    this.tag = tag;
    this.attrs = attrs;
    this.children = children2;
    this.self_closing = self_closing;
    this.void = void$;
  }
};
var Map2 = class extends CustomType {
  constructor(subtree) {
    super();
    this.subtree = subtree;
  }
};
var Attribute = class extends CustomType {
  constructor(x0, x1, as_property) {
    super();
    this[0] = x0;
    this[1] = x1;
    this.as_property = as_property;
  }
};
var Event = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
function attribute_to_event_handler(attribute2) {
  if (attribute2 instanceof Attribute) {
    return new Error(void 0);
  } else {
    let name = attribute2[0];
    let handler = attribute2[1];
    let name$1 = drop_start(name, 2);
    return new Ok([name$1, handler]);
  }
}
function do_element_list_handlers(elements2, handlers2, key) {
  return index_fold(
    elements2,
    handlers2,
    (handlers3, element2, index3) => {
      let key$1 = key + "-" + to_string(index3);
      return do_handlers(element2, handlers3, key$1);
    }
  );
}
function do_handlers(loop$element, loop$handlers, loop$key) {
  while (true) {
    let element2 = loop$element;
    let handlers2 = loop$handlers;
    let key = loop$key;
    if (element2 instanceof Text) {
      return handlers2;
    } else if (element2 instanceof Map2) {
      let subtree = element2.subtree;
      loop$element = subtree();
      loop$handlers = handlers2;
      loop$key = key;
    } else {
      let attrs = element2.attrs;
      let children2 = element2.children;
      let handlers$1 = fold(
        attrs,
        handlers2,
        (handlers3, attr) => {
          let $ = attribute_to_event_handler(attr);
          if ($.isOk()) {
            let name = $[0][0];
            let handler = $[0][1];
            return insert(handlers3, key + "-" + name, handler);
          } else {
            return handlers3;
          }
        }
      );
      return do_element_list_handlers(children2, handlers$1, key);
    }
  }
}
function handlers(element2) {
  return do_handlers(element2, new_map(), "0");
}

// build/dev/javascript/lustre/lustre/attribute.mjs
function attribute(name, value) {
  return new Attribute(name, identity(value), false);
}
function property(name, value) {
  return new Attribute(name, identity(value), true);
}
function on(name, handler) {
  return new Event("on" + name, handler);
}
function class$(name) {
  return attribute("class", name);
}
function none2() {
  return class$("");
}
function id(name) {
  return attribute("id", name);
}
function disabled(is_disabled) {
  return property("disabled", is_disabled);
}
function src(uri) {
  return attribute("src", uri);
}
function alt(text3) {
  return attribute("alt", text3);
}

// build/dev/javascript/lustre/lustre/element.mjs
function element(tag, attrs, children2) {
  if (tag === "area") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "base") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "br") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "col") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "embed") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "hr") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "img") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "input") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "link") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "meta") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "param") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "source") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "track") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else if (tag === "wbr") {
    return new Element("", "", tag, attrs, toList([]), false, true);
  } else {
    return new Element("", "", tag, attrs, children2, false, false);
  }
}
function text(content) {
  return new Text(content);
}

// build/dev/javascript/gleam_stdlib/gleam/set.mjs
var Set2 = class extends CustomType {
  constructor(dict2) {
    super();
    this.dict = dict2;
  }
};
function new$2() {
  return new Set2(new_map());
}
function contains2(set, member) {
  let _pipe = set.dict;
  let _pipe$1 = map_get(_pipe, member);
  return is_ok(_pipe$1);
}
var token = void 0;
function insert2(set, member) {
  return new Set2(insert(set.dict, member, token));
}

// build/dev/javascript/lustre/lustre/internals/patch.mjs
var Diff = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Emit = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Init = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
function is_empty_element_diff(diff2) {
  return isEqual(diff2.created, new_map()) && isEqual(
    diff2.removed,
    new$2()
  ) && isEqual(diff2.updated, new_map());
}

// build/dev/javascript/lustre/lustre/internals/runtime.mjs
var Attrs = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Batch = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Debug = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Dispatch = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var Emit2 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Event2 = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Shutdown = class extends CustomType {
};
var Subscribe = class extends CustomType {
  constructor(x0, x1) {
    super();
    this[0] = x0;
    this[1] = x1;
  }
};
var Unsubscribe = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};
var ForceModel = class extends CustomType {
  constructor(x0) {
    super();
    this[0] = x0;
  }
};

// build/dev/javascript/lustre/vdom.ffi.mjs
if (globalThis.customElements && !globalThis.customElements.get("lustre-fragment")) {
  globalThis.customElements.define(
    "lustre-fragment",
    class LustreFragment extends HTMLElement {
      constructor() {
        super();
      }
    }
  );
}
function morph(prev, next, dispatch) {
  let out;
  let stack = [{ prev, next, parent: prev.parentNode }];
  while (stack.length) {
    let { prev: prev2, next: next2, parent } = stack.pop();
    while (next2.subtree !== void 0)
      next2 = next2.subtree();
    if (next2.content !== void 0) {
      if (!prev2) {
        const created = document.createTextNode(next2.content);
        parent.appendChild(created);
        out ??= created;
      } else if (prev2.nodeType === Node.TEXT_NODE) {
        if (prev2.textContent !== next2.content)
          prev2.textContent = next2.content;
        out ??= prev2;
      } else {
        const created = document.createTextNode(next2.content);
        parent.replaceChild(created, prev2);
        out ??= created;
      }
    } else if (next2.tag !== void 0) {
      const created = createElementNode({
        prev: prev2,
        next: next2,
        dispatch,
        stack
      });
      if (!prev2) {
        parent.appendChild(created);
      } else if (prev2 !== created) {
        parent.replaceChild(created, prev2);
      }
      out ??= created;
    }
  }
  return out;
}
function createElementNode({ prev, next, dispatch, stack }) {
  const namespace = next.namespace || "http://www.w3.org/1999/xhtml";
  const canMorph = prev && prev.nodeType === Node.ELEMENT_NODE && prev.localName === next.tag && prev.namespaceURI === (next.namespace || "http://www.w3.org/1999/xhtml");
  const el = canMorph ? prev : namespace ? document.createElementNS(namespace, next.tag) : document.createElement(next.tag);
  let handlersForEl;
  if (!registeredHandlers.has(el)) {
    const emptyHandlers = /* @__PURE__ */ new Map();
    registeredHandlers.set(el, emptyHandlers);
    handlersForEl = emptyHandlers;
  } else {
    handlersForEl = registeredHandlers.get(el);
  }
  const prevHandlers = canMorph ? new Set(handlersForEl.keys()) : null;
  const prevAttributes = canMorph ? new Set(Array.from(prev.attributes, (a) => a.name)) : null;
  let className = null;
  let style2 = null;
  let innerHTML = null;
  if (canMorph && next.tag === "textarea") {
    const innertText = next.children[Symbol.iterator]().next().value?.content;
    if (innertText !== void 0)
      el.value = innertText;
  }
  const delegated = [];
  for (const attr of next.attrs) {
    const name = attr[0];
    const value = attr[1];
    if (attr.as_property) {
      if (el[name] !== value)
        el[name] = value;
      if (canMorph)
        prevAttributes.delete(name);
    } else if (name.startsWith("on")) {
      const eventName = name.slice(2);
      const callback = dispatch(value, eventName === "input");
      if (!handlersForEl.has(eventName)) {
        el.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      if (canMorph)
        prevHandlers.delete(eventName);
    } else if (name.startsWith("data-lustre-on-")) {
      const eventName = name.slice(15);
      const callback = dispatch(lustreServerEventHandler);
      if (!handlersForEl.has(eventName)) {
        el.addEventListener(eventName, lustreGenericEventHandler);
      }
      handlersForEl.set(eventName, callback);
      el.setAttribute(name, value);
      if (canMorph) {
        prevHandlers.delete(eventName);
        prevAttributes.delete(name);
      }
    } else if (name.startsWith("delegate:data-") || name.startsWith("delegate:aria-")) {
      el.setAttribute(name, value);
      delegated.push([name.slice(10), value]);
    } else if (name === "class") {
      className = className === null ? value : className + " " + value;
    } else if (name === "style") {
      style2 = style2 === null ? value : style2 + value;
    } else if (name === "dangerous-unescaped-html") {
      innerHTML = value;
    } else {
      if (el.getAttribute(name) !== value)
        el.setAttribute(name, value);
      if (name === "value" || name === "selected")
        el[name] = value;
      if (canMorph)
        prevAttributes.delete(name);
    }
  }
  if (className !== null) {
    el.setAttribute("class", className);
    if (canMorph)
      prevAttributes.delete("class");
  }
  if (style2 !== null) {
    el.setAttribute("style", style2);
    if (canMorph)
      prevAttributes.delete("style");
  }
  if (canMorph) {
    for (const attr of prevAttributes) {
      el.removeAttribute(attr);
    }
    for (const eventName of prevHandlers) {
      handlersForEl.delete(eventName);
      el.removeEventListener(eventName, lustreGenericEventHandler);
    }
  }
  if (next.tag === "slot") {
    window.queueMicrotask(() => {
      for (const child of el.assignedElements()) {
        for (const [name, value] of delegated) {
          if (!child.hasAttribute(name)) {
            child.setAttribute(name, value);
          }
        }
      }
    });
  }
  if (next.key !== void 0 && next.key !== "") {
    el.setAttribute("data-lustre-key", next.key);
  } else if (innerHTML !== null) {
    el.innerHTML = innerHTML;
    return el;
  }
  let prevChild = el.firstChild;
  let seenKeys = null;
  let keyedChildren = null;
  let incomingKeyedChildren = null;
  let firstChild = children(next).next().value;
  if (canMorph && firstChild !== void 0 && // Explicit checks are more verbose but truthy checks force a bunch of comparisons
  // we don't care about: it's never gonna be a number etc.
  firstChild.key !== void 0 && firstChild.key !== "") {
    seenKeys = /* @__PURE__ */ new Set();
    keyedChildren = getKeyedChildren(prev);
    incomingKeyedChildren = getKeyedChildren(next);
    for (const child of children(next)) {
      prevChild = diffKeyedChild(
        prevChild,
        child,
        el,
        stack,
        incomingKeyedChildren,
        keyedChildren,
        seenKeys
      );
    }
  } else {
    for (const child of children(next)) {
      stack.unshift({ prev: prevChild, next: child, parent: el });
      prevChild = prevChild?.nextSibling;
    }
  }
  while (prevChild) {
    const next2 = prevChild.nextSibling;
    el.removeChild(prevChild);
    prevChild = next2;
  }
  return el;
}
var registeredHandlers = /* @__PURE__ */ new WeakMap();
function lustreGenericEventHandler(event2) {
  const target = event2.currentTarget;
  if (!registeredHandlers.has(target)) {
    target.removeEventListener(event2.type, lustreGenericEventHandler);
    return;
  }
  const handlersForEventTarget = registeredHandlers.get(target);
  if (!handlersForEventTarget.has(event2.type)) {
    target.removeEventListener(event2.type, lustreGenericEventHandler);
    return;
  }
  handlersForEventTarget.get(event2.type)(event2);
}
function lustreServerEventHandler(event2) {
  const el = event2.currentTarget;
  const tag = el.getAttribute(`data-lustre-on-${event2.type}`);
  const data = JSON.parse(el.getAttribute("data-lustre-data") || "{}");
  const include = JSON.parse(el.getAttribute("data-lustre-include") || "[]");
  switch (event2.type) {
    case "input":
    case "change":
      include.push("target.value");
      break;
  }
  return {
    tag,
    data: include.reduce(
      (data2, property2) => {
        const path = property2.split(".");
        for (let i = 0, o = data2, e = event2; i < path.length; i++) {
          if (i === path.length - 1) {
            o[path[i]] = e[path[i]];
          } else {
            o[path[i]] ??= {};
            e = e[path[i]];
            o = o[path[i]];
          }
        }
        return data2;
      },
      { data }
    )
  };
}
function getKeyedChildren(el) {
  const keyedChildren = /* @__PURE__ */ new Map();
  if (el) {
    for (const child of children(el)) {
      const key = child?.key || child?.getAttribute?.("data-lustre-key");
      if (key)
        keyedChildren.set(key, child);
    }
  }
  return keyedChildren;
}
function diffKeyedChild(prevChild, child, el, stack, incomingKeyedChildren, keyedChildren, seenKeys) {
  while (prevChild && !incomingKeyedChildren.has(prevChild.getAttribute("data-lustre-key"))) {
    const nextChild = prevChild.nextSibling;
    el.removeChild(prevChild);
    prevChild = nextChild;
  }
  if (keyedChildren.size === 0) {
    stack.unshift({ prev: prevChild, next: child, parent: el });
    prevChild = prevChild?.nextSibling;
    return prevChild;
  }
  if (seenKeys.has(child.key)) {
    console.warn(`Duplicate key found in Lustre vnode: ${child.key}`);
    stack.unshift({ prev: null, next: child, parent: el });
    return prevChild;
  }
  seenKeys.add(child.key);
  const keyedChild = keyedChildren.get(child.key);
  if (!keyedChild && !prevChild) {
    stack.unshift({ prev: null, next: child, parent: el });
    return prevChild;
  }
  if (!keyedChild && prevChild !== null) {
    const placeholder = document.createTextNode("");
    el.insertBefore(placeholder, prevChild);
    stack.unshift({ prev: placeholder, next: child, parent: el });
    return prevChild;
  }
  if (!keyedChild || keyedChild === prevChild) {
    stack.unshift({ prev: prevChild, next: child, parent: el });
    prevChild = prevChild?.nextSibling;
    return prevChild;
  }
  el.insertBefore(keyedChild, prevChild);
  stack.unshift({ prev: keyedChild, next: child, parent: el });
  return prevChild;
}
function* children(element2) {
  for (const child of element2.children) {
    yield* forceChild(child);
  }
}
function* forceChild(element2) {
  if (element2.subtree !== void 0) {
    yield* forceChild(element2.subtree());
  } else {
    yield element2;
  }
}

// build/dev/javascript/lustre/lustre.ffi.mjs
var LustreClientApplication = class _LustreClientApplication {
  /**
   * @template Flags
   *
   * @param {object} app
   * @param {(flags: Flags) => [Model, Lustre.Effect<Msg>]} app.init
   * @param {(msg: Msg, model: Model) => [Model, Lustre.Effect<Msg>]} app.update
   * @param {(model: Model) => Lustre.Element<Msg>} app.view
   * @param {string | HTMLElement} selector
   * @param {Flags} flags
   *
   * @returns {Gleam.Ok<(action: Lustre.Action<Lustre.Client, Msg>>) => void>}
   */
  static start({ init: init4, update: update2, view: view2 }, selector, flags) {
    if (!is_browser())
      return new Error(new NotABrowser());
    const root = selector instanceof HTMLElement ? selector : document.querySelector(selector);
    if (!root)
      return new Error(new ElementNotFound(selector));
    const app = new _LustreClientApplication(root, init4(flags), update2, view2);
    return new Ok((action) => app.send(action));
  }
  /**
   * @param {Element} root
   * @param {[Model, Lustre.Effect<Msg>]} init
   * @param {(model: Model, msg: Msg) => [Model, Lustre.Effect<Msg>]} update
   * @param {(model: Model) => Lustre.Element<Msg>} view
   *
   * @returns {LustreClientApplication}
   */
  constructor(root, [init4, effects], update2, view2) {
    this.root = root;
    this.#model = init4;
    this.#update = update2;
    this.#view = view2;
    this.#tickScheduled = window.requestAnimationFrame(
      () => this.#tick(effects.all.toArray(), true)
    );
  }
  /** @type {Element} */
  root;
  /**
   * @param {Lustre.Action<Lustre.Client, Msg>} action
   *
   * @returns {void}
   */
  send(action) {
    if (action instanceof Debug) {
      if (action[0] instanceof ForceModel) {
        this.#tickScheduled = window.cancelAnimationFrame(this.#tickScheduled);
        this.#queue = [];
        this.#model = action[0][0];
        const vdom = this.#view(this.#model);
        const dispatch = (handler, immediate = false) => (event2) => {
          const result = handler(event2);
          if (result instanceof Ok) {
            this.send(new Dispatch(result[0], immediate));
          }
        };
        const prev = this.root.firstChild ?? this.root.appendChild(document.createTextNode(""));
        morph(prev, vdom, dispatch);
      }
    } else if (action instanceof Dispatch) {
      const msg = action[0];
      const immediate = action[1] ?? false;
      this.#queue.push(msg);
      if (immediate) {
        this.#tickScheduled = window.cancelAnimationFrame(this.#tickScheduled);
        this.#tick();
      } else if (!this.#tickScheduled) {
        this.#tickScheduled = window.requestAnimationFrame(() => this.#tick());
      }
    } else if (action instanceof Emit2) {
      const event2 = action[0];
      const data = action[1];
      this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
    } else if (action instanceof Shutdown) {
      this.#tickScheduled = window.cancelAnimationFrame(this.#tickScheduled);
      this.#model = null;
      this.#update = null;
      this.#view = null;
      this.#queue = null;
      while (this.root.firstChild) {
        this.root.firstChild.remove();
      }
    }
  }
  /** @type {Model} */
  #model;
  /** @type {(model: Model, msg: Msg) => [Model, Lustre.Effect<Msg>]} */
  #update;
  /** @type {(model: Model) => Lustre.Element<Msg>} */
  #view;
  /** @type {Array<Msg>} */
  #queue = [];
  /** @type {number | undefined} */
  #tickScheduled;
  /**
   * @param {Lustre.Effect<Msg>[]} effects
   */
  #tick(effects = []) {
    this.#tickScheduled = void 0;
    this.#flush(effects);
    const vdom = this.#view(this.#model);
    const dispatch = (handler, immediate = false) => (event2) => {
      const result = handler(event2);
      if (result instanceof Ok) {
        this.send(new Dispatch(result[0], immediate));
      }
    };
    const prev = this.root.firstChild ?? this.root.appendChild(document.createTextNode(""));
    morph(prev, vdom, dispatch);
  }
  #flush(effects = []) {
    while (this.#queue.length > 0) {
      const msg = this.#queue.shift();
      const [next, effect] = this.#update(this.#model, msg);
      effects = effects.concat(effect.all.toArray());
      this.#model = next;
    }
    while (effects.length > 0) {
      const effect = effects.shift();
      const dispatch = (msg) => this.send(new Dispatch(msg));
      const emit2 = (event2, data) => this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
      const select = () => {
      };
      const root = this.root;
      effect({ dispatch, emit: emit2, select, root });
    }
    if (this.#queue.length > 0) {
      this.#flush(effects);
    }
  }
};
var start = LustreClientApplication.start;
var LustreServerApplication = class _LustreServerApplication {
  static start({ init: init4, update: update2, view: view2, on_attribute_change }, flags) {
    const app = new _LustreServerApplication(
      init4(flags),
      update2,
      view2,
      on_attribute_change
    );
    return new Ok((action) => app.send(action));
  }
  constructor([model, effects], update2, view2, on_attribute_change) {
    this.#model = model;
    this.#update = update2;
    this.#view = view2;
    this.#html = view2(model);
    this.#onAttributeChange = on_attribute_change;
    this.#renderers = /* @__PURE__ */ new Map();
    this.#handlers = handlers(this.#html);
    this.#tick(effects.all.toArray());
  }
  send(action) {
    if (action instanceof Attrs) {
      for (const attr of action[0]) {
        const decoder = this.#onAttributeChange.get(attr[0]);
        if (!decoder)
          continue;
        const msg = decoder(attr[1]);
        if (msg instanceof Error)
          continue;
        this.#queue.push(msg);
      }
      this.#tick();
    } else if (action instanceof Batch) {
      this.#queue = this.#queue.concat(action[0].toArray());
      this.#tick(action[1].all.toArray());
    } else if (action instanceof Debug) {
    } else if (action instanceof Dispatch) {
      this.#queue.push(action[0]);
      this.#tick();
    } else if (action instanceof Emit2) {
      const event2 = new Emit(action[0], action[1]);
      for (const [_, renderer] of this.#renderers) {
        renderer(event2);
      }
    } else if (action instanceof Event2) {
      const handler = this.#handlers.get(action[0]);
      if (!handler)
        return;
      const msg = handler(action[1]);
      if (msg instanceof Error)
        return;
      this.#queue.push(msg[0]);
      this.#tick();
    } else if (action instanceof Subscribe) {
      const attrs = keys(this.#onAttributeChange);
      const patch = new Init(attrs, this.#html);
      this.#renderers = this.#renderers.set(action[0], action[1]);
      action[1](patch);
    } else if (action instanceof Unsubscribe) {
      this.#renderers = this.#renderers.delete(action[0]);
    }
  }
  #model;
  #update;
  #queue;
  #view;
  #html;
  #renderers;
  #handlers;
  #onAttributeChange;
  #tick(effects = []) {
    this.#flush(effects);
    const vdom = this.#view(this.#model);
    const diff2 = elements(this.#html, vdom);
    if (!is_empty_element_diff(diff2)) {
      const patch = new Diff(diff2);
      for (const [_, renderer] of this.#renderers) {
        renderer(patch);
      }
    }
    this.#html = vdom;
    this.#handlers = diff2.handlers;
  }
  #flush(effects = []) {
    while (this.#queue.length > 0) {
      const msg = this.#queue.shift();
      const [next, effect] = this.#update(this.#model, msg);
      effects = effects.concat(effect.all.toArray());
      this.#model = next;
    }
    while (effects.length > 0) {
      const effect = effects.shift();
      const dispatch = (msg) => this.send(new Dispatch(msg));
      const emit2 = (event2, data) => this.root.dispatchEvent(
        new CustomEvent(event2, {
          detail: data,
          bubbles: true,
          composed: true
        })
      );
      const select = () => {
      };
      const root = null;
      effect({ dispatch, emit: emit2, select, root });
    }
    if (this.#queue.length > 0) {
      this.#flush(effects);
    }
  }
};
var start_server_application = LustreServerApplication.start;
var is_browser = () => globalThis.window && window.document;
var prevent_default = (event2) => event2.preventDefault();

// build/dev/javascript/lustre/lustre.mjs
var App = class extends CustomType {
  constructor(init4, update2, view2, on_attribute_change) {
    super();
    this.init = init4;
    this.update = update2;
    this.view = view2;
    this.on_attribute_change = on_attribute_change;
  }
};
var ElementNotFound = class extends CustomType {
  constructor(selector) {
    super();
    this.selector = selector;
  }
};
var NotABrowser = class extends CustomType {
};
function application(init4, update2, view2) {
  return new App(init4, update2, view2, new None());
}
function simple(init4, update2, view2) {
  let init$1 = (flags) => {
    return [init4(flags), none()];
  };
  let update$1 = (model, msg) => {
    return [update2(model, msg), none()];
  };
  return application(init$1, update$1, view2);
}
function start2(app, selector, flags) {
  return guard(
    !is_browser(),
    new Error(new NotABrowser()),
    () => {
      return start(app, selector, flags);
    }
  );
}

// build/dev/javascript/lustre/lustre/element/html.mjs
function text2(content) {
  return text(content);
}
function h2(attrs, children2) {
  return element("h2", attrs, children2);
}
function div(attrs, children2) {
  return element("div", attrs, children2);
}
function br(attrs) {
  return element("br", attrs, toList([]));
}
function span(attrs, children2) {
  return element("span", attrs, children2);
}
function img(attrs) {
  return element("img", attrs, toList([]));
}
function button(attrs, children2) {
  return element("button", attrs, children2);
}

// build/dev/javascript/zereth/game_engine.mjs
var Game = class extends CustomType {
  constructor(board2, previous_board, history, current_player_color, remaining_moves, positioning, win) {
    super();
    this.board = board2;
    this.previous_board = previous_board;
    this.history = history;
    this.current_player_color = current_player_color;
    this.remaining_moves = remaining_moves;
    this.positioning = positioning;
    this.win = win;
  }
};
var Move = class extends CustomType {
  constructor(source_coords, target_coords) {
    super();
    this.source_coords = source_coords;
    this.target_coords = target_coords;
  }
};
var Reposition = class extends CustomType {
  constructor(strong_piece_source_coords, weak_piece_source_coords, target_coords, reposition_type) {
    super();
    this.strong_piece_source_coords = strong_piece_source_coords;
    this.weak_piece_source_coords = weak_piece_source_coords;
    this.target_coords = target_coords;
    this.reposition_type = reposition_type;
  }
};
var Capture = class extends CustomType {
  constructor(piece, trap_coords) {
    super();
    this.piece = piece;
    this.trap_coords = trap_coords;
  }
};
var Square = class extends CustomType {
  constructor(x, y, piece) {
    super();
    this.x = x;
    this.y = y;
    this.piece = piece;
  }
};
var Piece = class extends CustomType {
  constructor(kind, color, id2) {
    super();
    this.kind = kind;
    this.color = color;
    this.id = id2;
  }
};
var Elephant = class extends CustomType {
};
var Camel = class extends CustomType {
};
var Horse = class extends CustomType {
};
var Dog = class extends CustomType {
};
var Cat = class extends CustomType {
};
var Rabbit = class extends CustomType {
};
var Gold = class extends CustomType {
};
var Silver = class extends CustomType {
};
var Pull = class extends CustomType {
};
var Push = class extends CustomType {
};
var GoodToGo = class extends CustomType {
};
var Danger = class extends CustomType {
};
function new_debug_board() {
  let _pipe = range(1, 8);
  let _pipe$1 = flat_map(
    _pipe,
    (x) => {
      return map(
        range(1, 8),
        (y) => {
          return new Square(
            x,
            y,
            (() => {
              if (x === 2) {
                let y$1 = y;
                return new Some(new Piece(new Rabbit(), new Gold(), y$1));
              } else if (x === 7) {
                let y$1 = y;
                return new Some(new Piece(new Rabbit(), new Silver(), y$1));
              } else if (x === 1 && y === 1) {
                return new Some(new Piece(new Horse(), new Gold(), 1));
              } else if (x === 1 && y === 8) {
                return new Some(new Piece(new Horse(), new Gold(), 2));
              } else if (x === 8 && y === 1) {
                return new Some(new Piece(new Horse(), new Silver(), 1));
              } else if (x === 8 && y === 8) {
                return new Some(new Piece(new Horse(), new Silver(), 1));
              } else if (x === 1 && y === 2) {
                return new Some(new Piece(new Dog(), new Gold(), 1));
              } else if (x === 1 && y === 7) {
                return new Some(new Piece(new Dog(), new Gold(), 2));
              } else if (x === 8 && y === 2) {
                return new Some(new Piece(new Dog(), new Silver(), 1));
              } else if (x === 8 && y === 7) {
                return new Some(new Piece(new Dog(), new Silver(), 2));
              } else if (x === 1 && y === 3) {
                return new Some(new Piece(new Cat(), new Gold(), 1));
              } else if (x === 1 && y === 6) {
                return new Some(new Piece(new Cat(), new Gold(), 2));
              } else if (x === 8 && y === 3) {
                return new Some(new Piece(new Cat(), new Silver(), 1));
              } else if (x === 8 && y === 6) {
                return new Some(new Piece(new Cat(), new Silver(), 2));
              } else if (x === 1 && y === 4) {
                return new Some(new Piece(new Elephant(), new Gold(), 1));
              } else if (x === 8 && y === 4) {
                return new Some(new Piece(new Elephant(), new Silver(), 1));
              } else if (x === 1 && y === 5) {
                return new Some(new Piece(new Camel(), new Gold(), 1));
              } else if (x === 8 && y === 5) {
                return new Some(new Piece(new Camel(), new Silver(), 1));
              } else {
                return new None();
              }
            })()
          );
        }
      );
    }
  );
  return reverse(_pipe$1);
}
function new_debug_game() {
  return new Game(
    new_debug_board(),
    new None(),
    toList([]),
    new Gold(),
    4,
    false,
    false
  );
}
function update_board(board2, squares) {
  return fold(
    squares,
    board2,
    (acc, square) => {
      return map(
        acc,
        (s) => {
          let $ = s.x === square.x && s.y === square.y;
          if ($) {
            return square;
          } else {
            return s;
          }
        }
      );
    }
  );
}
function pass_turn(game) {
  let $ = game.remaining_moves === 0;
  if (!$) {
    return game;
  } else {
    let _record = game;
    return new Game(
      _record.board,
      new Some(game.board),
      _record.history,
      (() => {
        let $1 = game.current_player_color;
        if ($1 instanceof Gold) {
          return new Silver();
        } else {
          return new Gold();
        }
      })(),
      4,
      _record.positioning,
      _record.win
    );
  }
}
function execute_move(board2, source_square, target_square) {
  let _block;
  let _record = source_square;
  _block = new Square(_record.x, _record.y, new None());
  let updated_source_square = _block;
  let _block$1;
  let _record$1 = target_square;
  _block$1 = new Square(_record$1.x, _record$1.y, source_square.piece);
  let updated_target_square = _block$1;
  return update_board(
    board2,
    toList([updated_source_square, updated_target_square])
  );
}
function check_if_board_changed(game, updated_board) {
  let $ = game.previous_board;
  if ($ instanceof Some) {
    let previous_board = $[0];
    return !isEqual(previous_board, updated_board);
  } else {
    return true;
  }
}
function is_rabbit_moving_backwards(piece, source_square, target_square) {
  if (piece instanceof Piece && piece.kind instanceof Rabbit && piece.color instanceof Gold) {
    return target_square.x < source_square.x;
  } else if (piece instanceof Piece && piece.kind instanceof Rabbit && piece.color instanceof Silver) {
    return target_square.x > source_square.x;
  } else {
    return false;
  }
}
function is_placement_legal(piece, target_square) {
  return guard(
    !isEqual(target_square.piece, new None()),
    new Error("There is already a piece in the target square"),
    () => {
      let $ = piece.color;
      if ($ instanceof Gold) {
        return guard(
          !contains(toList([1, 2]), target_square.x),
          new Error("Attempeted to place a piece in a non-valid square"),
          () => {
            return new Ok(void 0);
          }
        );
      } else {
        return guard(
          !contains(toList([7, 8]), target_square.x),
          new Error("Attempeted to place a piece in a non-valid square"),
          () => {
            return new Ok(void 0);
          }
        );
      }
    }
  );
}
function is_positioning(board2) {
  let position_squares = filter(
    board2,
    (square) => {
      return square.x === 1 || square.x === 2 || square.x === 7 || square.x === 8;
    }
  );
  return any(
    position_squares,
    (square) => {
      return isEqual(square.piece, new None());
    }
  );
}
function is_rabbit_reached_opposite_end(board2) {
  let _pipe = board2;
  let _pipe$1 = filter(
    _pipe,
    (square) => {
      return contains(toList([1, 8]), square.x);
    }
  );
  return any(
    _pipe$1,
    (square) => {
      let $ = square.piece;
      let $1 = square.x;
      if ($ instanceof Some && $[0] instanceof Piece && $[0].kind instanceof Rabbit && $[0].color instanceof Gold && $1 === 8) {
        return true;
      } else if ($ instanceof Some && $[0] instanceof Piece && $[0].kind instanceof Rabbit && $[0].color instanceof Silver && $1 === 1) {
        return true;
      } else {
        return false;
      }
    }
  );
}
function player_has_all_pieces_captured(board2) {
  let $ = fold(
    board2,
    [toList([]), toList([])],
    (acc, square) => {
      let $1 = square.piece;
      if ($1 instanceof Some && isEqual($1[0].color, new Gold())) {
        let piece = $1[0];
        return [prepend(piece, acc[0]), acc[1]];
      } else if ($1 instanceof Some && isEqual($1[0].color, new Silver())) {
        let piece = $1[0];
        return [acc[0], prepend(piece, acc[1])];
      } else {
        return acc;
      }
    }
  );
  let gold_pieces = $[0];
  let silver_pieces = $[1];
  return is_empty(gold_pieces) || is_empty(silver_pieces);
}
function check_win(game) {
  let win_conditions = toList([
    is_rabbit_reached_opposite_end,
    player_has_all_pieces_captured
  ]);
  let win = any(
    win_conditions,
    (condition) => {
      return condition(game.board);
    }
  );
  let _record = game;
  return new Game(
    _record.board,
    _record.previous_board,
    _record.history,
    _record.current_player_color,
    _record.remaining_moves,
    _record.positioning,
    win
  );
}
function retrieve_square(board2, coords) {
  let $ = find2(
    board2,
    (square2) => {
      let x = coords[0];
      let y = coords[1];
      return square2.x === x && square2.y === y;
    }
  );
  if (!$.isOk()) {
    throw makeError(
      "let_assert",
      "game_engine",
      1044,
      "retrieve_square",
      "Pattern match failed, no pattern matched the value.",
      { value: $ }
    );
  }
  let square = $[0];
  return square;
}
function execute_placement(game, source_coords, target_piece, target_square) {
  let _block;
  if (source_coords instanceof Some) {
    let source_coords$1 = source_coords[0];
    let source_square = retrieve_square(game.board, source_coords$1);
    _block = toList([
      (() => {
        let _record2 = target_square;
        return new Square(_record2.x, _record2.y, new Some(target_piece));
      })(),
      (() => {
        let _record2 = source_square;
        return new Square(_record2.x, _record2.y, new None());
      })()
    ]);
  } else {
    _block = toList([
      (() => {
        let _record2 = target_square;
        return new Square(_record2.x, _record2.y, new Some(target_piece));
      })()
    ]);
  }
  let updated_squares = _block;
  let board2 = update_board(game.board, updated_squares);
  let _record = game;
  return new Game(
    board2,
    _record.previous_board,
    _record.history,
    _record.current_player_color,
    _record.remaining_moves,
    _record.positioning,
    _record.win
  );
}
function retrieve_square_from_piece(board2, piece) {
  let $ = find2(
    board2,
    (square2) => {
      return isEqual(square2.piece, new Some(piece));
    }
  );
  if (!$.isOk()) {
    throw makeError(
      "let_assert",
      "game_engine",
      1055,
      "retrieve_square_from_piece",
      "Pattern match failed, no pattern matched the value.",
      { value: $ }
    );
  }
  let square = $[0];
  return square;
}
function adjacent_coords(coords) {
  let x = coords[0];
  let y = coords[1];
  let possible = toList([[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]]);
  return filter(
    possible,
    (coord) => {
      let x$1 = coord[0];
      let y$1 = coord[1];
      return x$1 >= 1 && x$1 <= 8 && y$1 >= 1 && y$1 <= 8;
    }
  );
}
function is_reposition_legal(source_square, target_square) {
  return guard(
    isEqual(source_square.piece, new None()),
    new Error("Not a piece in the source square"),
    () => {
      return guard(
        !isEqual(target_square.piece, new None()),
        new Error("Already a piece in the target square"),
        () => {
          let adjacent_coords$1 = adjacent_coords(
            [source_square.x, source_square.y]
          );
          return guard(
            !contains(
              adjacent_coords$1,
              [target_square.x, target_square.y]
            ),
            new Error("Not an adyacent square"),
            () => {
              return new Ok(void 0);
            }
          );
        }
      );
    }
  );
}
function execute_reposition(game, strong_piece, strong_piece_square, weak_piece, weak_piece_square, target_square, reposition_type) {
  let _block;
  if (reposition_type instanceof Pull) {
    _block = [strong_piece_square, target_square];
  } else {
    _block = [weak_piece_square, target_square];
  }
  let $ = _block;
  let first_movement_source = $[0];
  let first_movement_target = $[1];
  let $1 = is_reposition_legal(first_movement_source, first_movement_target);
  if ($1.isOk()) {
    let _block$1;
    if (reposition_type instanceof Pull) {
      _block$1 = [
        (() => {
          let _record = strong_piece_square;
          return new Square(_record.x, _record.y, new None());
        })(),
        weak_piece_square,
        (() => {
          let _record = target_square;
          return new Square(_record.x, _record.y, new Some(strong_piece));
        })()
      ];
    } else {
      _block$1 = [
        strong_piece_square,
        (() => {
          let _record = weak_piece_square;
          return new Square(_record.x, _record.y, new None());
        })(),
        (() => {
          let _record = target_square;
          return new Square(_record.x, _record.y, new Some(weak_piece));
        })()
      ];
    }
    let $2 = _block$1;
    let strong_piece_square$1 = $2[0];
    let weak_piece_square$1 = $2[1];
    let target_square$1 = $2[2];
    let _block$2;
    if (reposition_type instanceof Pull) {
      _block$2 = [weak_piece_square$1, strong_piece_square$1];
    } else {
      _block$2 = [strong_piece_square$1, weak_piece_square$1];
    }
    let $3 = _block$2;
    let second_movement_source = $3[0];
    let second_movement_target = $3[1];
    let $4 = is_reposition_legal(second_movement_source, second_movement_target);
    if ($4.isOk()) {
      let _block$3;
      if (reposition_type instanceof Pull) {
        _block$3 = [
          (() => {
            let _record = strong_piece_square$1;
            return new Square(_record.x, _record.y, new Some(weak_piece));
          })(),
          (() => {
            let _record = weak_piece_square$1;
            return new Square(_record.x, _record.y, new None());
          })(),
          target_square$1
        ];
      } else {
        _block$3 = [
          (() => {
            let _record = strong_piece_square$1;
            return new Square(_record.x, _record.y, new None());
          })(),
          (() => {
            let _record = weak_piece_square$1;
            return new Square(_record.x, _record.y, new Some(strong_piece));
          })(),
          target_square$1
        ];
      }
      let $5 = _block$3;
      let strong_piece_square$2 = $5[0];
      let weak_piece_square$2 = $5[1];
      let target_square$2 = $5[2];
      return new Ok(
        update_board(
          game.board,
          toList([weak_piece_square$2, target_square$2, strong_piece_square$2])
        )
      );
    } else {
      let reason = $4[0];
      return new Error(reason);
    }
  } else {
    let reason = $1[0];
    return new Error(reason);
  }
}
function adjacent_pieces(board2, coords) {
  let _pipe = coords;
  let _pipe$1 = adjacent_coords(_pipe);
  return filter_map(
    _pipe$1,
    (a_coords) => {
      let $ = find2(
        board2,
        (s) => {
          return s.x === a_coords[0] && s.y === a_coords[1];
        }
      );
      if (!$.isOk()) {
        throw makeError(
          "let_assert",
          "game_engine",
          1078,
          "",
          "Pattern match failed, no pattern matched the value.",
          { value: $ }
        );
      }
      let square = $[0];
      let $1 = square.piece;
      if ($1 instanceof Some) {
        let piece = $1[0];
        return new Ok(piece);
      } else {
        return new Error("No piece found in the adjacent square");
      }
    }
  );
}
function ortogonal_path(x1, x2, y1, y2) {
  let is_x_axis = x1 === x2;
  let dx = x2 - x1;
  let dy = y2 - y1;
  let _block;
  if (is_x_axis) {
    _block = absolute_value(dy);
  } else {
    _block = absolute_value(dx);
  }
  let steps = _block;
  let _block$1;
  if (is_x_axis) {
    let $ = dy > 0;
    if ($) {
      _block$1 = 1;
    } else {
      _block$1 = -1;
    }
  } else {
    let $ = dx > 0;
    if ($) {
      _block$1 = 1;
    } else {
      _block$1 = -1;
    }
  }
  let dir = _block$1;
  let _pipe = range(1, steps);
  return map(
    _pipe,
    (i) => {
      if (is_x_axis) {
        return [x1, y1 + dir * i];
      } else {
        return [x1 + dir * i, y1];
      }
    }
  );
}
function diagonal_paths(x1, y1, x2, y2) {
  let dx = x2 - x1;
  let dy = y2 - y1;
  let _block;
  let $ = dx > 0;
  if ($) {
    _block = 1;
  } else {
    _block = -1;
  }
  let x_dir = _block;
  let _block$1;
  let $1 = dy > 0;
  if ($1) {
    _block$1 = 1;
  } else {
    _block$1 = -1;
  }
  let y_dir = _block$1;
  let length3 = absolute_value(x2 - x1);
  if (length3 === 1) {
    let path1 = toList([[x1 + x_dir, y1], [x2, y2]]);
    let path2 = toList([[x1, y1 + y_dir], [x2, y2]]);
    return toList([path1, path2]);
  } else if (length3 === 2) {
    let path1 = toList([
      [x1 + x_dir, y1],
      [x1 + x_dir, y1 + y_dir],
      [x1 + x_dir * 2, y1 + y_dir],
      [x2, y2]
    ]);
    let path2 = toList([
      [x1, y1 + y_dir],
      [x1 + x_dir, y1 + y_dir],
      [x1 + x_dir, y1 + y_dir * 2],
      [x2, y2]
    ]);
    return toList([path1, path2]);
  } else {
    throw makeError(
      "panic",
      "game_engine",
      1297,
      "diagonal_paths",
      "Not valid",
      {}
    );
  }
}
function multi_axis_paths(x1, y1, x2, y2) {
  let dx = absolute_value(x2 - x1);
  let dy = absolute_value(y2 - y1);
  let total_length = dx + dy;
  return guard(
    !contains(toList([2, 3, 4]), total_length),
    toList([]),
    () => {
      let _block;
      let $ = x2 > x1;
      if ($) {
        _block = 1;
      } else {
        _block = -1;
      }
      let x_dir = _block;
      let _block$1;
      let $1 = y2 > y1;
      if ($1) {
        _block$1 = 1;
      } else {
        _block$1 = -1;
      }
      let y_dir = _block$1;
      let _block$2;
      if (dx === 2 && dy === 1) {
        let path1 = toList([[x1 + x_dir, y1], [x1 + x_dir * 2, y1], [x2, y2]]);
        let path2 = toList([
          [x1, y1 + y_dir],
          [x1 + x_dir, y1 + y_dir],
          [x2, y2]
        ]);
        _block$2 = toList([path1, path2]);
      } else if (dx === 1 && dy === 2) {
        let path1 = toList([[x1, y1 + y_dir], [x1, y1 + y_dir * 2], [x2, y2]]);
        let path2 = toList([
          [x1 + x_dir, y1],
          [x1 + x_dir, y1 + y_dir],
          [x2, y2]
        ]);
        _block$2 = toList([path1, path2]);
      } else if (dx === 3 && dy === 1) {
        let path1 = toList([
          [x1 + x_dir, y1],
          [x1 + x_dir * 2, y1],
          [x1 + x_dir * 3, y1],
          [x2, y2]
        ]);
        let path2 = toList([
          [x1, y1 + y_dir],
          [x1 + x_dir, y1 + y_dir],
          [x1 + x_dir * 2, y1 + y_dir],
          [x2, y2]
        ]);
        _block$2 = toList([path1, path2]);
      } else if (dx === 1 && dy === 3) {
        let path1 = toList([
          [x1, y1 + y_dir],
          [x1, y1 + y_dir * 2],
          [x1, y1 + y_dir * 3],
          [x2, y2]
        ]);
        let path2 = toList([
          [x1 + x_dir, y1],
          [x1 + x_dir, y1 + y_dir],
          [x1 + x_dir, y1 + y_dir * 2],
          [x2, y2]
        ]);
        _block$2 = toList([path1, path2]);
      } else {
        _block$2 = toList([]);
      }
      let _pipe = _block$2;
      return filter(
        _pipe,
        (path) => {
          return all(
            path,
            (coord) => {
              let x = coord[0];
              let y = coord[1];
              return x >= 1 && x <= 8 && y >= 1 && y <= 8;
            }
          );
        }
      );
    }
  );
}
function piece_color_to_string(piece_color) {
  if (piece_color instanceof Gold) {
    return "gold";
  } else {
    return "silver";
  }
}
function piece_kind_to_string(piece_kind) {
  if (piece_kind instanceof Elephant) {
    return "elephant";
  } else if (piece_kind instanceof Camel) {
    return "camel";
  } else if (piece_kind instanceof Horse) {
    return "horse";
  } else if (piece_kind instanceof Dog) {
    return "dog";
  } else if (piece_kind instanceof Cat) {
    return "cat";
  } else {
    return "rabbit";
  }
}
var trap_squares = /* @__PURE__ */ toList([
  [3, 3],
  [3, 6],
  [6, 3],
  [6, 6]
]);
function undo_last_move(loop$game) {
  while (true) {
    let game = loop$game;
    let $ = game.history;
    if (!$.atLeastLength(1)) {
      throw makeError(
        "let_assert",
        "game_engine",
        871,
        "undo_last_move",
        "Pattern match failed, no pattern matched the value.",
        { value: $ }
      );
    }
    let last_move = $.head;
    let history = $.tail;
    if (last_move instanceof Move) {
      let source_coords = last_move.source_coords;
      let target_coords = last_move.target_coords;
      let source_square = retrieve_square(game.board, source_coords);
      let target_square = retrieve_square(game.board, target_coords);
      let $1 = target_square.piece;
      if (!($1 instanceof Some)) {
        throw makeError(
          "let_assert",
          "game_engine",
          877,
          "undo_last_move",
          "Pattern match failed, no pattern matched the value.",
          { value: $1 }
        );
      }
      let target_piece = $1[0];
      let updated_board = update_board(
        game.board,
        toList([
          (() => {
            let _record2 = source_square;
            return new Square(_record2.x, _record2.y, new Some(target_piece));
          })(),
          (() => {
            let _record2 = target_square;
            return new Square(_record2.x, _record2.y, new None());
          })()
        ])
      );
      let _record = game;
      return new Game(
        updated_board,
        _record.previous_board,
        history,
        _record.current_player_color,
        game.remaining_moves + 1,
        _record.positioning,
        _record.win
      );
    } else if (last_move instanceof Reposition) {
      let strong_piece_source_coords = last_move.strong_piece_source_coords;
      let weak_piece_source_coords = last_move.weak_piece_source_coords;
      let target_coords = last_move.target_coords;
      let reposition_type = last_move.reposition_type;
      let strong_piece_source_square = retrieve_square(
        game.board,
        strong_piece_source_coords
      );
      let weak_piece_source_square = retrieve_square(
        game.board,
        weak_piece_source_coords
      );
      let target_square = retrieve_square(game.board, target_coords);
      let _block;
      if (reposition_type instanceof Pull) {
        let $2 = target_square.piece;
        if (!($2 instanceof Some)) {
          throw makeError(
            "let_assert",
            "game_engine",
            908,
            "undo_last_move",
            "Pattern match failed, no pattern matched the value.",
            { value: $2 }
          );
        }
        let strong_piece2 = $2[0];
        let $3 = strong_piece_source_square.piece;
        if (!($3 instanceof Some)) {
          throw makeError(
            "let_assert",
            "game_engine",
            909,
            "undo_last_move",
            "Pattern match failed, no pattern matched the value.",
            { value: $3 }
          );
        }
        let weak_piece2 = $3[0];
        _block = [strong_piece2, weak_piece2];
      } else {
        let $2 = weak_piece_source_square.piece;
        if (!($2 instanceof Some)) {
          throw makeError(
            "let_assert",
            "game_engine",
            914,
            "undo_last_move",
            "Pattern match failed, no pattern matched the value.",
            { value: $2 }
          );
        }
        let strong_piece2 = $2[0];
        let $3 = target_square.piece;
        if (!($3 instanceof Some)) {
          throw makeError(
            "let_assert",
            "game_engine",
            915,
            "undo_last_move",
            "Pattern match failed, no pattern matched the value.",
            { value: $3 }
          );
        }
        let weak_piece2 = $3[0];
        _block = [strong_piece2, weak_piece2];
      }
      let $1 = _block;
      let strong_piece = $1[0];
      let weak_piece = $1[1];
      let updated_board = update_board(
        game.board,
        toList([
          (() => {
            let _record2 = strong_piece_source_square;
            return new Square(_record2.x, _record2.y, new Some(strong_piece));
          })(),
          (() => {
            let _record2 = weak_piece_source_square;
            return new Square(_record2.x, _record2.y, new Some(weak_piece));
          })(),
          (() => {
            let _record2 = target_square;
            return new Square(_record2.x, _record2.y, new None());
          })()
        ])
      );
      let _record = game;
      return new Game(
        updated_board,
        _record.previous_board,
        history,
        _record.current_player_color,
        game.remaining_moves + 2,
        _record.positioning,
        _record.win
      );
    } else {
      let piece = last_move.piece;
      let trap_coords = last_move.trap_coords;
      let $1 = contains(trap_squares, trap_coords);
      if (!$1) {
        throw makeError(
          "let_assert",
          "game_engine",
          937,
          "undo_last_move",
          "Pattern match failed, no pattern matched the value.",
          { value: $1 }
        );
      }
      let trap_square = retrieve_square(game.board, trap_coords);
      let updated_board = update_board(
        game.board,
        toList([
          (() => {
            let _record = trap_square;
            return new Square(_record.x, _record.y, new Some(piece));
          })()
        ])
      );
      loop$game = (() => {
        let _record = game;
        return new Game(
          updated_board,
          _record.previous_board,
          history,
          _record.current_player_color,
          _record.remaining_moves,
          _record.positioning,
          _record.win
        );
      })();
    }
  }
}
function is_piece_captured(board2, square) {
  return guard(
    !contains(trap_squares, [square.x, square.y]),
    false,
    () => {
      let $ = square.piece;
      if ($ instanceof None) {
        return false;
      } else {
        let piece = $[0];
        let _block;
        let _pipe = adjacent_pieces(board2, [square.x, square.y]);
        _block = any(
          _pipe,
          (p) => {
            return isEqual(p.color, piece.color);
          }
        );
        let has_adjacent_allies = _block;
        return !has_adjacent_allies;
      }
    }
  );
}
function perform_captures(game) {
  let $ = fold(
    trap_squares,
    [toList([]), toList([])],
    (acc, trap_coords) => {
      let trap_square = retrieve_square(game.board, trap_coords);
      let $1 = trap_square.piece;
      if ($1 instanceof None) {
        return acc;
      } else {
        let piece = $1[0];
        let $2 = is_piece_captured(game.board, trap_square);
        if (!$2) {
          return acc;
        } else {
          let updated_squares2 = prepend(
            (() => {
              let _record2 = trap_square;
              return new Square(_record2.x, _record2.y, new None());
            })(),
            acc[0]
          );
          let updated_history2 = prepend(
            new Capture(piece, trap_coords),
            acc[1]
          );
          return [updated_squares2, updated_history2];
        }
      }
    }
  );
  let updated_squares = $[0];
  let new_history_records = $[1];
  let updated_board = update_board(game.board, updated_squares);
  let updated_history = fold(
    new_history_records,
    game.history,
    (acc, record) => {
      return prepend(record, acc);
    }
  );
  let _record = game;
  return new Game(
    updated_board,
    _record.previous_board,
    updated_history,
    _record.current_player_color,
    _record.remaining_moves,
    _record.positioning,
    _record.win
  );
}
var pieces_strength = /* @__PURE__ */ toList([
  [/* @__PURE__ */ new Elephant(), 6],
  [/* @__PURE__ */ new Camel(), 5],
  [/* @__PURE__ */ new Horse(), 4],
  [/* @__PURE__ */ new Dog(), 3],
  [/* @__PURE__ */ new Cat(), 2],
  [/* @__PURE__ */ new Rabbit(), 1]
]);
function is_piece_stronger(piece1, piece2) {
  let _block;
  let $ = find2(
    pieces_strength,
    (p) => {
      return isEqual(p[0], piece1.kind);
    }
  );
  if ($.isOk()) {
    let strength = $[0][1];
    _block = strength;
  } else {
    _block = 0;
  }
  let strength1 = _block;
  let _block$1;
  let $1 = find2(
    pieces_strength,
    (p) => {
      return isEqual(p[0], piece2.kind);
    }
  );
  if ($1.isOk()) {
    let strength = $1[0][1];
    _block$1 = strength;
  } else {
    _block$1 = 0;
  }
  let strength2 = _block$1;
  return strength1 > strength2;
}
function is_piece_frozen(board2, piece, source_square) {
  let adjacent_pieces$1 = adjacent_pieces(
    board2,
    [source_square.x, source_square.y]
  );
  let $ = fold(
    adjacent_pieces$1,
    [toList([]), toList([])],
    (acc, p) => {
      let $1 = isEqual(p.color, piece.color);
      if ($1) {
        return [prepend(p, acc[0]), acc[1]];
      } else {
        return [acc[0], prepend(p, acc[1])];
      }
    }
  );
  let ally_pieces = $[0];
  let enemy_pieces = $[1];
  return any(
    enemy_pieces,
    (enemy_piece) => {
      return is_piece_stronger(enemy_piece, piece);
    }
  ) && is_empty(ally_pieces);
}
function reposition_piece(game, strong_piece, weak_piece, target_coords) {
  return guard(
    game.remaining_moves < 2,
    new Error("Not enough moves remaining in the current turn"),
    () => {
      return guard(
        isEqual(strong_piece.color, weak_piece.color),
        new Error("Both pieces must be of different colors"),
        () => {
          return guard(
            !is_piece_stronger(strong_piece, weak_piece),
            new Error("Strong piece is actually not stronger than weak piece"),
            () => {
              let strong_piece_square = retrieve_square_from_piece(
                game.board,
                strong_piece
              );
              let weak_piece_square = retrieve_square_from_piece(
                game.board,
                weak_piece
              );
              let strong_piece_adjacent_coords = adjacent_coords(
                [strong_piece_square.x, strong_piece_square.y]
              );
              let target_square = retrieve_square(game.board, target_coords);
              let _block;
              let $ = contains(
                strong_piece_adjacent_coords,
                target_coords
              );
              if ($) {
                _block = new Pull();
              } else {
                _block = new Push();
              }
              let reposition_type = _block;
              let updated_board = execute_reposition(
                game,
                strong_piece,
                strong_piece_square,
                weak_piece,
                weak_piece_square,
                target_square,
                reposition_type
              );
              if (updated_board.isOk()) {
                let updated_board$1 = updated_board[0];
                return guard(
                  game.remaining_moves === 2 && !check_if_board_changed(
                    game,
                    updated_board$1
                  ),
                  new Error(
                    "Invalid move. A turn has to produce a net change in the board"
                  ),
                  () => {
                    let new_history_record = new Reposition(
                      [strong_piece_square.x, strong_piece_square.y],
                      [weak_piece_square.x, weak_piece_square.y],
                      [target_square.x, target_square.y],
                      reposition_type
                    );
                    let _block$1;
                    let _record = game;
                    _block$1 = new Game(
                      updated_board$1,
                      _record.previous_board,
                      prepend(new_history_record, game.history),
                      _record.current_player_color,
                      game.remaining_moves - 2,
                      _record.positioning,
                      _record.win
                    );
                    return new Ok(
                      (() => {
                        let _pipe = _block$1;
                        let _pipe$1 = perform_captures(_pipe);
                        return check_win(_pipe$1);
                      })()
                    );
                  }
                );
              } else {
                let reason = updated_board[0];
                return new Error(reason);
              }
            }
          );
        }
      );
    }
  );
}
function possible_moves(start3, remaining_moves, visited, board2, piece) {
  return guard(
    remaining_moves === 0,
    toList([]),
    () => {
      let directions = toList([[0, 1], [0, -1], [1, 0], [-1, 0]]);
      let _block;
      let _pipe = directions;
      let _pipe$1 = map(
        _pipe,
        (dir) => {
          return [start3.x + dir[0], start3.y + dir[1]];
        }
      );
      _block = filter(
        _pipe$1,
        (pos) => {
          return guard(
            contains2(visited, pos),
            false,
            () => {
              return guard(
                pos[0] < 1 || pos[0] > 8 || pos[1] < 1 || pos[1] > 8,
                false,
                () => {
                  return guard(
                    !isEqual(retrieve_square(board2, pos).piece, new None()),
                    false,
                    () => {
                      return guard(
                        is_piece_frozen(
                          board2,
                          piece,
                          retrieve_square(board2, pos)
                        ),
                        false,
                        () => {
                          return guard(
                            is_rabbit_moving_backwards(
                              piece,
                              start3,
                              retrieve_square(board2, pos)
                            ),
                            false,
                            () => {
                              return true;
                            }
                          );
                        }
                      );
                    }
                  );
                }
              );
            }
          );
        }
      );
      let next_positions = _block;
      let new_visited = insert2(visited, [start3.x, start3.y]);
      let _block$1;
      let _pipe$2 = next_positions;
      _block$1 = flat_map(
        _pipe$2,
        (pos) => {
          return possible_moves(
            retrieve_square(board2, pos),
            remaining_moves - 1,
            new_visited,
            board2,
            piece
          );
        }
      );
      let further_positions = _block$1;
      return fold(
        further_positions,
        next_positions,
        (acc, path) => {
          return prepend(path, acc);
        }
      );
    }
  );
}
function valid_coords_for_piece(board2, remaining_moves, source_coords, piece) {
  let visited = new$2();
  let source_square = retrieve_square(board2, source_coords);
  let _pipe = possible_moves(
    source_square,
    remaining_moves,
    visited,
    board2,
    piece
  );
  return map(
    _pipe,
    (pos) => {
      let simulated_board = update_board(
        board2,
        toList([
          new Square(source_square.x, source_square.y, new None()),
          new Square(pos[0], pos[1], new Some(piece))
        ])
      );
      let $ = is_piece_captured(
        simulated_board,
        retrieve_square(simulated_board, pos)
      );
      if ($) {
        return [pos, new Danger()];
      } else {
        return [pos, new GoodToGo()];
      }
    }
  );
}
function is_movement_legal(board2, remaining_moves, source_square, target_square) {
  return guard(
    isEqual(source_square.piece, new None()),
    new Error("Not a piece in the source square"),
    () => {
      return guard(
        !isEqual(target_square.piece, new None()),
        new Error("Already a piece in the target square"),
        () => {
          let $ = source_square.piece;
          if (!($ instanceof Some)) {
            throw makeError(
              "let_assert",
              "game_engine",
              408,
              "",
              "Pattern match failed, no pattern matched the value.",
              { value: $ }
            );
          }
          let piece = $[0];
          let _block;
          let _pipe = valid_coords_for_piece(
            board2,
            remaining_moves,
            [source_square.x, source_square.y],
            piece
          );
          _block = map(
            _pipe,
            (tuple) => {
              let valid_coord = tuple[0];
              return valid_coord;
            }
          );
          let valid_coords = _block;
          return guard(
            !contains(valid_coords, [target_square.x, target_square.y]),
            new Error("Not a valid square square"),
            () => {
              return new Ok(void 0);
            }
          );
        }
      );
    }
  );
}
function validate_move(board2, remaining_moves, piece, source_square, target_square) {
  let $ = is_movement_legal(
    board2,
    remaining_moves,
    source_square,
    target_square
  );
  let $1 = is_piece_frozen(board2, piece, source_square);
  let $2 = is_rabbit_moving_backwards(piece, source_square, target_square);
  if ($.isOk() && !$1 && !$2) {
    return new Ok(void 0);
  } else if (!$.isOk()) {
    let reason = $[0];
    return new Error(reason);
  } else if ($1) {
    return new Error("Piece is frozen");
  } else {
    return new Error("Rabbits cannot move backwards");
  }
}
function is_path_valid(board2, path, actual_square) {
  let $ = fold(
    path,
    [true, board2, actual_square],
    (acc, target_coords) => {
      let state2 = acc[0];
      let board$1 = acc[1];
      let actual_square$1 = acc[2];
      return guard(
        !state2,
        [false, board$1, actual_square$1],
        () => {
          let $1 = actual_square$1.piece;
          if (!($1 instanceof Some)) {
            throw makeError(
              "let_assert",
              "game_engine",
              1200,
              "",
              "Pattern match failed, no pattern matched the value.",
              { value: $1 }
            );
          }
          let piece = $1[0];
          let intermediate_board = update_board(
            board$1,
            toList([
              new Square(actual_square$1.x, actual_square$1.y, new None()),
              new Square(target_coords[0], target_coords[1], new Some(piece))
            ])
          );
          let target_square = retrieve_square(intermediate_board, target_coords);
          let $2 = is_piece_captured(intermediate_board, target_square) || is_piece_frozen(
            intermediate_board,
            piece,
            target_square
          );
          if ($2) {
            return [false, intermediate_board, actual_square$1];
          } else {
            return [true, intermediate_board, target_square];
          }
        }
      );
    }
  );
  let state = $[0];
  return state;
}
function remove_invalid_paths(paths, start_square, board2) {
  return filter(
    paths,
    (_capture) => {
      return is_path_valid(board2, _capture, start_square);
    }
  );
}
function generate_move_history_records(board2, source_square, target_square) {
  let is_diagonal = absolute_value(source_square.x - target_square.x) === absolute_value(
    source_square.y - target_square.y
  );
  let _block;
  if (source_square instanceof Square && target_square instanceof Square && !is_diagonal && (source_square.x === target_square.x || source_square.y === target_square.y)) {
    let x1 = source_square.x;
    let y1 = source_square.y;
    let x2 = target_square.x;
    let y2 = target_square.y;
    _block = ortogonal_path(x1, x2, y1, y2);
  } else if (source_square instanceof Square && target_square instanceof Square && is_diagonal) {
    let x1 = source_square.x;
    let y1 = source_square.y;
    let x2 = target_square.x;
    let y2 = target_square.y;
    let _block$1;
    let _pipe2 = diagonal_paths(x1, y1, x2, y2);
    _block$1 = remove_invalid_paths(_pipe2, source_square, board2);
    let valid_paths = _block$1;
    if (valid_paths.atLeastLength(1)) {
      let path = valid_paths.head;
      _block = path;
    } else {
      throw makeError(
        "panic",
        "game_engine",
        345,
        "generate_move_history_records",
        "Invalid move",
        {}
      );
    }
  } else {
    let x1 = source_square.x;
    let y1 = source_square.y;
    let x2 = target_square.x;
    let y2 = target_square.y;
    let _block$1;
    let _pipe2 = multi_axis_paths(x1, y1, x2, y2);
    _block$1 = remove_invalid_paths(_pipe2, source_square, board2);
    let paths = _block$1;
    if (paths.hasLength(1)) {
      let path = paths.head;
      _block = path;
    } else if (paths.atLeastLength(1)) {
      let path = paths.head;
      _block = path;
    } else {
      throw makeError(
        "panic",
        "game_engine",
        360,
        "generate_move_history_records",
        "Invalid move",
        {}
      );
    }
  }
  let coords = _block;
  let _pipe = fold(
    coords,
    toList([]),
    (acc, coord) => {
      let _block$1;
      let $ = first(acc);
      if ($.isOk() && $[0] instanceof Move) {
        let target_coords = $[0].target_coords;
        _block$1 = target_coords;
      } else {
        _block$1 = [source_square.x, source_square.y];
      }
      let recent = _block$1;
      let new$3 = new Move(recent, coord);
      return prepend(new$3, acc);
    }
  );
  return reverse(_pipe);
}
function move_piece(game, piece, target_coords) {
  let source_square = retrieve_square_from_piece(game.board, piece);
  let target_square = retrieve_square(game.board, target_coords);
  let $ = validate_move(
    game.board,
    game.remaining_moves,
    piece,
    source_square,
    target_square
  );
  if ($.isOk()) {
    let _block;
    if (source_square instanceof Square && target_square instanceof Square && (source_square.x !== target_square.x && source_square.y === target_square.y)) {
      let x1 = source_square.x;
      let y1 = source_square.y;
      let x2 = target_square.x;
      let y2 = target_square.y;
      _block = absolute_value(x2 - x1);
    } else if (source_square instanceof Square && target_square instanceof Square && (source_square.x === target_square.x && source_square.y !== target_square.y)) {
      let x1 = source_square.x;
      let y1 = source_square.y;
      let x2 = target_square.x;
      let y2 = target_square.y;
      _block = absolute_value(y2 - y1);
    } else {
      let x1 = source_square.x;
      let y1 = source_square.y;
      let x2 = target_square.x;
      let y2 = target_square.y;
      _block = absolute_value(x2 - x1) + absolute_value(y2 - y1);
    }
    let length3 = _block;
    return guard(
      game.remaining_moves < length3,
      new Error("Not enough moves remaining"),
      () => {
        let updated_board = execute_move(
          game.board,
          source_square,
          target_square
        );
        return guard(
          game.remaining_moves === length3 && !check_if_board_changed(
            game,
            updated_board
          ),
          new Error(
            "Invalid move. A turn has to produce a net change in the board"
          ),
          () => {
            let new_history_records = generate_move_history_records(
              game.board,
              source_square,
              target_square
            );
            let history = fold(
              new_history_records,
              game.history,
              (acc, record) => {
                return prepend(record, acc);
              }
            );
            let _block$1;
            let _record = game;
            _block$1 = new Game(
              updated_board,
              _record.previous_board,
              history,
              _record.current_player_color,
              game.remaining_moves - length3,
              _record.positioning,
              _record.win
            );
            return new Ok(
              (() => {
                let _pipe = _block$1;
                let _pipe$1 = perform_captures(_pipe);
                return check_win(_pipe$1);
              })()
            );
          }
        );
      }
    );
  } else {
    let reason = $[0];
    return new Error("Not a valid move because: " + reason);
  }
}
var pieces_amount_per_player = /* @__PURE__ */ toList([
  [/* @__PURE__ */ new Elephant(), 1],
  [/* @__PURE__ */ new Camel(), 1],
  [/* @__PURE__ */ new Horse(), 2],
  [/* @__PURE__ */ new Dog(), 2],
  [/* @__PURE__ */ new Cat(), 2],
  [/* @__PURE__ */ new Rabbit(), 8]
]);
function get_aviable_pieces_to_place(board2) {
  let colors = toList([new Gold(), new Silver()]);
  let piece_types = toList([
    new Elephant(),
    new Camel(),
    new Horse(),
    new Dog(),
    new Cat(),
    new Rabbit()
  ]);
  let get_piece_amount = (kind) => {
    let $ = find2(
      pieces_amount_per_player,
      (p) => {
        return isEqual(p[0], kind);
      }
    );
    if ($.isOk()) {
      let amount = $[0][1];
      return amount;
    } else {
      return 0;
    }
  };
  let get_pieces = (color, kind) => {
    let piece_ids = get_piece_amount(kind);
    return map(
      range(1, piece_ids),
      (id2) => {
        return new Piece(kind, color, id2);
      }
    );
  };
  let pieces = flat_map(
    colors,
    (color) => {
      return flat_map(
        piece_types,
        (kind) => {
          return get_pieces(color, kind);
        }
      );
    }
  );
  let position_squares = filter(
    board2,
    (square) => {
      return square.x === 1 || square.x === 2 || square.x === 7 || square.x === 8;
    }
  );
  let _pipe = pieces;
  let _pipe$1 = filter(
    _pipe,
    (piece) => {
      return all(
        position_squares,
        (square) => {
          return !isEqual(square.piece, new Some(piece));
        }
      );
    }
  );
  return reverse(_pipe$1);
}
function pass_player_color(game) {
  let _block;
  let _pipe = get_aviable_pieces_to_place(game.board);
  _block = filter(
    _pipe,
    (piece) => {
      return isEqual(piece.color, new Gold());
    }
  );
  let gold_pieces_to_place = _block;
  let $ = is_empty(gold_pieces_to_place);
  if ($) {
    return new Silver();
  } else {
    return new Gold();
  }
}
function place_piece(game, target_coords, target_piece, source_coords) {
  let target_square = retrieve_square(game.board, target_coords);
  let $ = is_placement_legal(target_piece, target_square);
  if (!$.isOk()) {
    let reason = $[0];
    return new Error("Placement not legal because: " + reason);
  } else {
    let updated_game = execute_placement(
      game,
      source_coords,
      target_piece,
      target_square
    );
    let positioning = is_positioning(updated_game.board);
    let _block;
    if (positioning) {
      _block = pass_player_color(updated_game);
    } else {
      _block = new Gold();
    }
    let current_player_color = _block;
    let _block$1;
    if (positioning) {
      _block$1 = 0;
    } else {
      _block$1 = 4;
    }
    let remaining_moves = _block$1;
    return new Ok(
      (() => {
        let _record = updated_game;
        return new Game(
          _record.board,
          _record.previous_board,
          _record.history,
          current_player_color,
          remaining_moves,
          positioning,
          _record.win
        );
      })()
    );
  }
}

// build/dev/javascript/zereth/logger.mjs
function piece_to_string(piece) {
  return piece_color_to_string(piece.color) + " " + piece_kind_to_string(
    piece.kind
  );
}
function coords_to_string(coords) {
  return "x: " + to_string(coords[0]) + ", y: " + to_string(
    coords[1]
  );
}
function print_move_error(error, piece, target_coords) {
  let piece_log = "Piece: " + piece_to_string(piece);
  let target_coords_log = "Target coords: " + coords_to_string(target_coords);
  console_error("Move error");
  console_error(error);
  console_log(piece_log);
  return console_log(target_coords_log);
}
function print_reposition_error(error, strong_piece, weak_piece, target_coords) {
  let strong_piece_log = "Strong piece: " + piece_to_string(strong_piece);
  let weak_piece_log = "Weak piece: " + piece_to_string(weak_piece);
  let target_coords_log = "Target coords: " + coords_to_string(target_coords);
  console_error("Reposition error");
  console_error(error);
  console_log(strong_piece_log);
  console_log(weak_piece_log);
  return console_log(target_coords_log);
}
function print_placement_error(error, piece, target_coords) {
  let piece_log = "Piece: " + piece_to_string(piece);
  let target_coords_log = "Target coords: " + coords_to_string(target_coords);
  console_error("Placement error");
  console_error(error);
  console_log(piece_log);
  return console_log(target_coords_log);
}

// build/dev/javascript/zereth/model.mjs
var Model2 = class extends CustomType {
  constructor(game, opting_piece, enemy_opting_piece, valid_coords, error, opting_square) {
    super();
    this.game = game;
    this.opting_piece = opting_piece;
    this.enemy_opting_piece = enemy_opting_piece;
    this.valid_coords = valid_coords;
    this.error = error;
    this.opting_square = opting_square;
  }
};
function init2(_) {
  return new Model2(
    new_debug_game(),
    new None(),
    new None(),
    new None(),
    new None(),
    new None()
  );
}

// build/dev/javascript/zereth/events.mjs
var Opting = class extends CustomType {
  constructor(piece) {
    super();
    this.piece = piece;
  }
};
var EnemyOpting = class extends CustomType {
  constructor(piece) {
    super();
    this.piece = piece;
  }
};
var SquareOpting = class extends CustomType {
  constructor(square) {
    super();
    this.square = square;
  }
};
var PlacePiece = class extends CustomType {
  constructor(target_square) {
    super();
    this.target_square = target_square;
  }
};
var MovePiece = class extends CustomType {
  constructor(target_square) {
    super();
    this.target_square = target_square;
  }
};
var RepositionPiece = class extends CustomType {
  constructor(target_square) {
    super();
    this.target_square = target_square;
  }
};
var Undo = class extends CustomType {
};
var PassTurn = class extends CustomType {
};
var Nothing = class extends CustomType {
};
function set_game(_, game) {
  return new Model2(
    game,
    new None(),
    new None(),
    new None(),
    new None(),
    new None()
  );
}
function set_error(model, error) {
  let _record = model;
  return new Model2(
    _record.game,
    new None(),
    new None(),
    new None(),
    new Some(error),
    new None()
  );
}
function place_piece2(model, target_coords, piece, source_coords) {
  let $ = place_piece(
    model.game,
    target_coords,
    piece,
    source_coords
  );
  if ($.isOk()) {
    let game = $[0];
    return set_game(model, game);
  } else {
    let error = $[0];
    print_placement_error(error, piece, target_coords);
    return set_error(model, error);
  }
}
function move_piece2(model, piece, target_coords) {
  let $ = move_piece(model.game, piece, target_coords);
  if ($.isOk()) {
    let game = $[0];
    return set_game(model, game);
  } else {
    let error = $[0];
    print_move_error(error, piece, target_coords);
    return set_error(model, error);
  }
}
function reposition_piece2(model, strong_piece, weak_piece, target_coords) {
  let $ = reposition_piece(
    model.game,
    strong_piece,
    weak_piece,
    target_coords
  );
  if ($.isOk()) {
    let game = $[0];
    return set_game(model, game);
  } else {
    let error = $[0];
    print_reposition_error(
      error,
      strong_piece,
      weak_piece,
      target_coords
    );
    return set_error(model, error);
  }
}
function process_msg(model, msg) {
  if (msg instanceof Undo) {
    return set_game(model, undo_last_move(model.game));
  } else if (msg instanceof PassTurn) {
    let _record = model;
    return new Model2(
      pass_turn(model.game),
      _record.opting_piece,
      _record.enemy_opting_piece,
      _record.valid_coords,
      _record.error,
      _record.opting_square
    );
  } else if (msg instanceof Opting) {
    let piece = msg.piece;
    let _block;
    let $ = model.opting_piece;
    if ($ instanceof Some && isEqual($[0], piece)) {
      let p = $[0];
      _block = new None();
    } else {
      _block = new Some(piece);
    }
    let opting_piece = _block;
    return guard(
      !model.game.positioning && is_piece_frozen(
        model.game.board,
        piece,
        retrieve_square_from_piece(model.game.board, piece)
      ),
      model,
      () => {
        let _block$1;
        let $1 = model.game.positioning;
        if (opting_piece instanceof Some && !$1) {
          let p = opting_piece[0];
          let source_square = retrieve_square_from_piece(
            model.game.board,
            p
          );
          _block$1 = new Some(
            valid_coords_for_piece(
              model.game.board,
              model.game.remaining_moves,
              [source_square.x, source_square.y],
              p
            )
          );
        } else {
          _block$1 = new None();
        }
        let valid_coords = _block$1;
        let _record = model;
        return new Model2(
          _record.game,
          opting_piece,
          _record.enemy_opting_piece,
          valid_coords,
          new None(),
          _record.opting_square
        );
      }
    );
  } else if (msg instanceof EnemyOpting) {
    let piece = msg.piece;
    let _block;
    let $ = model.enemy_opting_piece;
    if ($ instanceof Some && isEqual($[0], piece)) {
      let p = $[0];
      _block = new None();
    } else {
      _block = new Some(piece);
    }
    let enemy_opting_piece = _block;
    let _record = model;
    return new Model2(
      _record.game,
      _record.opting_piece,
      enemy_opting_piece,
      _record.valid_coords,
      new None(),
      _record.opting_square
    );
  } else if (msg instanceof SquareOpting) {
    let square = msg.square;
    let $ = model.valid_coords;
    let $1 = model.game.positioning;
    if ($1) {
      let $2 = model.opting_piece;
      if ($2 instanceof Some && $2[0] instanceof Piece && $2[0].color instanceof Gold && (square.x === 1 || square.x === 2)) {
        let square$1 = square;
        let _record = model;
        return new Model2(
          _record.game,
          _record.opting_piece,
          _record.enemy_opting_piece,
          _record.valid_coords,
          _record.error,
          new Some(square$1)
        );
      } else if ($2 instanceof Some && $2[0] instanceof Piece && $2[0].color instanceof Silver && (square.x === 7 || square.x === 8)) {
        let square$1 = square;
        let _record = model;
        return new Model2(
          _record.game,
          _record.opting_piece,
          _record.enemy_opting_piece,
          _record.valid_coords,
          _record.error,
          new Some(square$1)
        );
      } else {
        let _record = model;
        return new Model2(
          _record.game,
          _record.opting_piece,
          _record.enemy_opting_piece,
          _record.valid_coords,
          _record.error,
          new None()
        );
      }
    } else if ($ instanceof Some) {
      let coords = $[0];
      let coords$1 = map(
        coords,
        (tuple) => {
          let pos = tuple[0];
          return pos;
        }
      );
      let $2 = contains(coords$1, [square.x, square.y]);
      if ($2) {
        let _record = model;
        return new Model2(
          _record.game,
          _record.opting_piece,
          _record.enemy_opting_piece,
          _record.valid_coords,
          _record.error,
          new Some(square)
        );
      } else {
        let _record = model;
        return new Model2(
          _record.game,
          _record.opting_piece,
          _record.enemy_opting_piece,
          _record.valid_coords,
          _record.error,
          new None()
        );
      }
    } else {
      let _record = model;
      return new Model2(
        _record.game,
        _record.opting_piece,
        _record.enemy_opting_piece,
        _record.valid_coords,
        _record.error,
        new None()
      );
    }
  } else if (msg instanceof PlacePiece) {
    let target_square = msg.target_square;
    let $ = model.opting_piece;
    if ($ instanceof Some && isEqual($[0].color, model.game.current_player_color)) {
      let piece = $[0];
      let $1 = find2(
        model.game.board,
        (square) => {
          return isEqual(square.piece, new Some(piece));
        }
      );
      if ($1.isOk()) {
        let source_square = $1[0];
        return place_piece2(
          model,
          [target_square.x, target_square.y],
          piece,
          new Some([source_square.x, source_square.y])
        );
      } else {
        return place_piece2(
          model,
          [target_square.x, target_square.y],
          piece,
          new None()
        );
      }
    } else {
      return model;
    }
  } else if (msg instanceof MovePiece) {
    let target_square = msg.target_square;
    let $ = model.opting_piece;
    if ($ instanceof Some && !isEqual(target_square.piece, new Some($[0]))) {
      let piece = $[0];
      return move_piece2(model, piece, [target_square.x, target_square.y]);
    } else {
      return model;
    }
  } else if (msg instanceof RepositionPiece) {
    let target_square = msg.target_square;
    let $ = model.opting_piece;
    let $1 = model.enemy_opting_piece;
    if ($ instanceof Some && $1 instanceof Some && (!isEqual(target_square.piece, new Some($[0])) && !isEqual(
      target_square.piece,
      new Some($1[0])
    ))) {
      let strong_piece = $[0];
      let weak_piece = $1[0];
      return reposition_piece2(
        model,
        strong_piece,
        weak_piece,
        [target_square.x, target_square.y]
      );
    } else {
      return model;
    }
  } else {
    return model;
  }
}

// build/dev/javascript/lustre/lustre/event.mjs
function on2(name, handler) {
  return on(name, handler);
}
function on_click(msg) {
  return on2("click", (_) => {
    return new Ok(msg);
  });
}
function on_mouse_down(msg) {
  return on2("mousedown", (_) => {
    return new Ok(msg);
  });
}
function on_mouse_over(msg) {
  return on2("mouseover", (_) => {
    return new Ok(msg);
  });
}

// build/dev/javascript/zereth/ffi/browser_ffi.mjs
function hideDragImage(event2) {
  let ghostImage = document.createElement("div");
  ghostImage.style.width = "1px";
  ghostImage.style.height = "1px";
  ghostImage.style.position = "absolute";
  ghostImage.style.top = "-100px";
  document.body.appendChild(ghostImage);
  event2.dataTransfer.setDragImage(ghostImage, 0, 0);
  function cleanup() {
    if (document.body.contains(ghostImage)) {
      document.body.removeChild(ghostImage);
    }
    event2.target.removeEventListener("dragend", cleanup);
  }
  event2.target.addEventListener("dragend", cleanup);
}

// build/dev/javascript/zereth/ui/piece.mjs
function get_piece_asset_name(piece) {
  let color = piece_color_to_string(piece.color);
  let kind = piece_kind_to_string(piece.kind);
  return "assets/pieces/" + color + "_" + kind + ".png";
}
function render(piece, class_name, is_ghost) {
  let piece_alt = piece_color_to_string(piece.color) + "_" + piece_kind_to_string(
    piece.kind
  );
  return div(
    toList([
      class$("piece"),
      class$(class_name),
      (() => {
        if (is_ghost) {
          return class$("ghost");
        } else {
          return none2();
        }
      })(),
      attribute("draggable", "true")
    ]),
    toList([
      img(
        toList([
          src(get_piece_asset_name(piece)),
          alt(piece_alt)
        ])
      )
    ])
  );
}

// build/dev/javascript/zereth/ui/board.mjs
function build_piece_id(piece) {
  return "piece-" + piece_color_to_string(piece.color) + "-" + piece_kind_to_string(
    piece.kind
  ) + "-" + to_string(piece.id);
}
function build_square_id(square) {
  return "square-" + to_string(square.x) + "-" + to_string(
    square.y
  );
}
function on_dragover(msg) {
  return on2(
    "dragover",
    (evt) => {
      prevent_default(evt);
      return new Ok(msg);
    }
  );
}
function on_drop(msg) {
  return on2("drop", (_) => {
    return new Ok(msg);
  });
}
function on_dragstart(msg) {
  return on2(
    "dragstart",
    (evt) => {
      hideDragImage(evt);
      return new Ok(msg);
    }
  );
}
function piece_events(square, current_player_color) {
  let $ = square.piece;
  if ($ instanceof Some && isEqual($[0].color, current_player_color)) {
    let piece = $[0];
    let color = current_player_color;
    return toList([
      on_click(new Opting(piece)),
      on_dragstart(new Opting(piece))
    ]);
  } else if ($ instanceof Some) {
    let piece = $[0];
    return toList([on_click(new EnemyOpting(piece))]);
  } else {
    return toList([]);
  }
}
function render_square(square, current_player_color, positioning, opting_square, opting_piece, enemy_opting_piece, valid_coords) {
  let _block;
  let $ = square.piece;
  if ($ instanceof Some && opting_piece instanceof Some && isEqual($[0], opting_piece[0])) {
    let p1 = $[0];
    let p2 = opting_piece[0];
    _block = "opting";
  } else if ($ instanceof Some && enemy_opting_piece instanceof Some && isEqual($[0], enemy_opting_piece[0])) {
    let p1 = $[0];
    let p2 = enemy_opting_piece[0];
    _block = "enemy-opting";
  } else {
    _block = "";
  }
  let piece_additional_classes = _block;
  let is_ghost = isEqual(opting_square, new Some(square));
  let _block$1;
  let $1 = square.piece;
  if ($1 instanceof Some && !is_ghost) {
    let piece = $1[0];
    _block$1 = toList([render(piece, piece_additional_classes, is_ghost)]);
  } else if ($1 instanceof None && opting_piece instanceof Some && is_ghost) {
    let opt_piece = opting_piece[0];
    _block$1 = toList([
      render(opt_piece, piece_additional_classes, is_ghost)
    ]);
  } else {
    _block$1 = toList([]);
  }
  let piece_element = _block$1;
  let _block$2;
  if (positioning) {
    _block$2 = toList([]);
  } else {
    _block$2 = piece_events(square, current_player_color);
  }
  let piece_events$1 = _block$2;
  let _block$3;
  let $2 = square.piece;
  if ($2 instanceof Some) {
    let piece = $2[0];
    _block$3 = build_piece_id(piece);
  } else {
    _block$3 = build_square_id(square);
  }
  let square_id = _block$3;
  let _block$4;
  if (valid_coords instanceof Some) {
    let valid_coords$1 = valid_coords[0];
    let $3 = find2(
      valid_coords$1,
      (tuple) => {
        let pos = tuple[0];
        return pos[0] === square.x && pos[1] === square.y;
      }
    );
    if ($3.isOk()) {
      let coords = $3[0];
      let kind = coords[1];
      if (kind instanceof GoodToGo) {
        _block$4 = class$("valid good-to-go");
      } else {
        _block$4 = class$("valid danger");
      }
    } else {
      _block$4 = none2();
    }
  } else {
    _block$4 = none2();
  }
  let valid_coords_class = _block$4;
  let _block$5;
  if (positioning) {
    _block$5 = new PlacePiece(square);
  } else {
    if (opting_piece instanceof Some && enemy_opting_piece instanceof Some) {
      _block$5 = new RepositionPiece(square);
    } else {
      _block$5 = new MovePiece(square);
    }
  }
  let interaction_message = _block$5;
  return div(
    prepend(
      id(square_id),
      prepend(
        class$("square"),
        prepend(
          (() => {
            let $3 = contains(
              trap_squares,
              [square.x, square.y]
            );
            if ($3) {
              return class$("trap");
            } else {
              return none2();
            }
          })(),
          prepend(
            valid_coords_class,
            prepend(
              on_mouse_over(new SquareOpting(square)),
              prepend(
                on_click(interaction_message),
                prepend(
                  on_dragover(new SquareOpting(square)),
                  prepend(on_drop(interaction_message), piece_events$1)
                )
              )
            )
          )
        )
      )
    ),
    piece_element
  );
}
function render_board(model) {
  return div(
    toList([
      class$("board"),
      class$(
        (() => {
          let $ = model.game.win;
          if ($) {
            return "game-over";
          } else {
            return "";
          }
        })()
      )
    ]),
    (() => {
      let $ = model.game.win;
      if ($) {
        return prepend(
          div(
            toList([class$("winner-overlay")]),
            toList([
              h2(
                toList([class$("winner-message")]),
                toList([
                  text2("Game Over!"),
                  br(toList([])),
                  text2(
                    (() => {
                      let $1 = model.game.current_player_color;
                      if ($1 instanceof Gold) {
                        return "Silver";
                      } else {
                        return "Gold";
                      }
                    })() + " wins!"
                  )
                ])
              )
            ])
          ),
          map(
            model.game.board,
            (square) => {
              return render_square(
                square,
                model.game.current_player_color,
                model.game.positioning,
                model.opting_square,
                model.opting_piece,
                model.enemy_opting_piece,
                model.valid_coords
              );
            }
          )
        );
      } else {
        return map(
          model.game.board,
          (square) => {
            return render_square(
              square,
              model.game.current_player_color,
              model.game.positioning,
              model.opting_square,
              model.opting_piece,
              model.enemy_opting_piece,
              model.valid_coords
            );
          }
        );
      }
    })()
  );
}
function render_positioning_board(model) {
  let available_pieces = get_aviable_pieces_to_place(
    model.game.board
  );
  return div(
    toList([]),
    toList([
      div(
        toList([class$("available-pieces silver")]),
        map(
          filter(
            available_pieces,
            (piece) => {
              return isEqual(piece.color, new Silver());
            }
          ),
          (piece) => {
            return div(
              toList([
                on_click(new Opting(piece)),
                on_mouse_down(new Opting(piece)),
                on_dragstart(new Nothing())
              ]),
              toList([render(piece, "", false)])
            );
          }
        )
      ),
      render_board(model),
      div(
        toList([class$("available-pieces gold")]),
        map(
          filter(
            available_pieces,
            (piece) => {
              return isEqual(piece.color, new Gold());
            }
          ),
          (piece) => {
            return div(
              toList([
                on_click(new Opting(piece)),
                on_mouse_down(new Opting(piece)),
                on_dragstart(new Nothing())
              ]),
              toList([render(piece, "", false)])
            );
          }
        )
      )
    ])
  );
}
function render2(model, positioning) {
  if (positioning) {
    return render_positioning_board(model);
  } else {
    return render_board(model);
  }
}

// build/dev/javascript/zereth/ui/game_status.mjs
function render3(model) {
  return div(
    toList([class$("game-status")]),
    toList([
      (() => {
        let $ = model.error;
        if ($ instanceof Some) {
          let error = $[0];
          return div(
            toList([class$("error-message")]),
            toList([text2("\u26A0 " + error)])
          );
        } else {
          return text2("");
        }
      })(),
      div(
        toList([]),
        toList([
          text2("Current player: "),
          span(
            toList([
              class$("current-player"),
              class$(
                (() => {
                  let $ = model.game.current_player_color;
                  if ($ instanceof Gold) {
                    return "gold";
                  } else {
                    return "silver";
                  }
                })()
              )
            ]),
            toList([
              text2(
                (() => {
                  let $ = model.game.current_player_color;
                  if ($ instanceof Gold) {
                    return "Gold";
                  } else {
                    return "Silver";
                  }
                })()
              )
            ])
          ),
          (() => {
            let $ = model.game.positioning;
            if ($) {
              return text2(" | Positioning");
            } else {
              return text2(
                " | Moves remaining: " + to_string(
                  model.game.remaining_moves
                )
              );
            }
          })()
        ])
      )
    ])
  );
}

// build/dev/javascript/zereth/ui/player_controls.mjs
function could_undo(game) {
  return length(game.history) > 0 && game.positioning === false && game.remaining_moves !== 4;
}
function render4(model, undo_msg, pass_turn_msg) {
  return div(
    toList([class$("player-controls")]),
    toList([
      button(
        toList([
          class$("undo-button"),
          disabled(!could_undo(model.game)),
          on_click(undo_msg)
        ]),
        toList([text2("Undo")])
      ),
      button(
        toList([
          class$("pass-turn-button"),
          disabled(model.game.remaining_moves !== 0),
          on_click(pass_turn_msg)
        ]),
        toList([text2("Pass turn")])
      )
    ])
  );
}

// build/dev/javascript/zereth/ui.mjs
function board(model, positioning) {
  return render2(model, positioning);
}
function game_status(model) {
  return render3(model);
}
function player_controls(model, undo_msg, pass_turn_msg) {
  return render4(model, undo_msg, pass_turn_msg);
}

// build/dev/javascript/zereth/zereth.mjs
function init3(flags) {
  return init2(flags);
}
function update(model, msg) {
  return guard(
    model.game.win,
    model,
    () => {
      return process_msg(model, msg);
    }
  );
}
function view(model) {
  let board_view = board(model, model.game.positioning);
  let game_status_view = game_status(model);
  return div(
    toList([class$("game-container")]),
    toList([
      game_status_view,
      board_view,
      (() => {
        let $ = model.game.positioning;
        if ($) {
          return text2("");
        } else {
          return player_controls(
            model,
            new Undo(),
            new PassTurn()
          );
        }
      })()
    ])
  );
}
function main() {
  let app = simple(init3, update, view);
  let $ = start2(app, "#app", void 0);
  if (!$.isOk()) {
    throw makeError(
      "let_assert",
      "zereth",
      39,
      "main",
      "Pattern match failed, no pattern matched the value.",
      { value: $ }
    );
  }
  return void 0;
}

// build/.lustre/entry.mjs
main();
