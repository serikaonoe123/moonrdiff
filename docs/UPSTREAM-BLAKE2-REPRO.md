# BLAKE2b exact-block finalization reproducer

Observed in cc06b/mooncry 0.71.0, lib/blake2.mbt. Prepared for upstream review; no issue or message has been sent.

For input bytes `byte[i] = (i * 73 + 255) % 256`, i = 0..127, the first 16 bytes of BLAKE2b with 32-byte output are:

| Implementation | Digest prefix |
| --- | --- |
| Python hashlib and librsync 2.3.4 | b007ed92d585554b8dab5301cd34f860 |
| Unmodified mooncry 0.71.0 | 71a08de32ba525c860cf3c5737f1829a |

Python reference:

```python
import hashlib
data = bytes((i * 73 + 255) % 256 for i in range(128))
print(hashlib.blake2b(data, digest_size=32).hexdigest())
```

MoonBit reproduction with cc06b/mooncry/lib imported as @crypto:

```moonbit
let data = Bytes::from_array(Array::makei(128, i => ((i * 73 + 255) % 256).to_byte())[:])
println(@crypto.bytes_to_hex(@crypto.blake2b(data, 32)))
```

Cause: the nonfinal compression loop consumes every full block, then compresses an empty final block for inputs whose size is a positive multiple of 128. Preserve the last full block for final compression instead. The local adaptation uses `len - offset > 128`, avoiding addition overflow as well.

The local correction preserves the upstream Apache-2.0 license. Regression vectors cover 0, 1, 127, 128, 129, 255, 256, 257, 384 and 512 bytes with independent hashlib expected values. Linux interoperability also compares complete signatures against rdiff, including the 128-byte and multiple-block boundaries.

Original source and hash, modified-file declaration, and full license are retained under third_party/mooncry_blake2. Replacement by a verified upstream release is preferred once available.
