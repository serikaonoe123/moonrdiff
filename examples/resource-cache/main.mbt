///|
struct ReadResult {
  data : String
  error : String
} derive(@json.FromJson)

///|
struct Offer {
  schema : Int32
  basis_bytes : Int32
  basis_sha256 : String
  signature_hex : String
} derive(ToJson, @json.FromJson)

///|
struct Manifest {
  schema : Int32
  delivery : String
  basis_sha256 : String
  target_sha256 : String
  target_bytes : Int32
  payload_sha256 : String
} derive(ToJson, @json.FromJson)

///|
let file_limit : Int32 = 8 * 1024 * 1024

///|
fn read(path : String, limit~ : Int32 = file_limit) -> Bytes raise {
  let result : ReadResult = @json.from_json(@json.parse(read_file(path, limit)))
  guard result.error.is_empty() else { fail(result.error) }
  @hex.decode(result.data[:])
}

///|
fn save(path : String, data : Bytes) -> Unit raise {
  let error = write_file(path, data)
  guard error.is_empty() else { fail(error) }
}

///|
fn[T : ToJson] json_bytes(value : T) -> Bytes {
  @utf8.encode(value.to_json().stringify()[:])
}

///|
fn[T : @json.FromJson] parse(data : Bytes) -> T raise {
  @json.from_json(@json.parse(@utf8.decode(data)))
}

///|
fn manifest(
  delivery : String,
  offer : Offer,
  target : Bytes,
  payload : Bytes,
) -> Manifest {
  {
    schema: 1,
    delivery,
    basis_sha256: offer.basis_sha256,
    target_sha256: sha256(target),
    target_bytes: target.length(),
    payload_sha256: sha256(payload),
  }
}

///|
fn offer(basis_path : String, offer_path : String) -> Json raise {
  let basis = read(basis_path)
  let signature = @rdiff.signature(basis, block_size=1024, max_blocks=8192)
  let offer : Offer = {
    schema: 1,
    basis_bytes: basis.length(),
    basis_sha256: sha256(basis),
    signature_hex: @hex.encode(signature),
  }
  let bytes = json_bytes(offer)
  save(offer_path, bytes)
  { "offer_bytes": bytes.length(), "basis_sha256": offer.basis_sha256 }
}

///|
/// Publisher receives the offer and target only; it has no basis path.
fn build(
  offer_path : String,
  target_path : String,
  output : String,
) -> Json raise {
  let offer_bytes = read(offer_path, limit=1024 * 1024)
  let offer : Offer = parse(offer_bytes)
  guard offer.schema == 1 &&
    offer.basis_bytes >= 0 &&
    offer.basis_bytes <= file_limit else {
    fail("invalid offer")
  }
  guard @hex.decode(offer.basis_sha256[:]).length() == 32 else {
    fail("invalid basis identity")
  }
  let target = read(target_path)
  let signature = @rdiff.parse_signature(
    @hex.decode(offer.signature_hex[:]),
    max_blocks=8192,
  )
  let delta = @rdiff.delta(
    signature,
    target,
    basis_size=offer.basis_bytes,
    max_candidate_checks=1_000_000,
    max_delta_size=2 * file_limit,
  )
  let delta_manifest = json_bytes(manifest("delta", offer, target, delta))
  let full_manifest = json_bytes(manifest("full", offer, target, target))
  let first_delta = offer_bytes.length() +
    delta.length() +
    delta_manifest.length()
  let full = target.length() + full_manifest.length()
  let use_delta = first_delta < full
  let payload = if use_delta { delta } else { target }
  let selected_manifest = if use_delta { delta_manifest } else { full_manifest }
  save(output + "/payload.bin", payload)
  save(output + "/manifest.json", selected_manifest)
  {
    "delivery": if use_delta {
      "delta"
    } else {
      "full"
    },
    "offer_bytes": offer_bytes.length(),
    "delta_bytes": delta.length(),
    "delta_manifest_bytes": delta_manifest.length(),
    "full_manifest_bytes": full_manifest.length(),
    "target_bytes": target.length(),
    "first_delta_bytes": first_delta,
    "direct_full_bytes": full,
    // Offer has already crossed the wire when the publisher makes this choice.
    "actual_exchange_bytes": offer_bytes.length() +
    payload.length() +
    selected_manifest.length(),
    "selected_remaining_bytes": payload.length() + selected_manifest.length(),
    "target_sha256": sha256(target),
  }
}

///|
fn apply(
  basis_path : String,
  manifest_path : String,
  payload_path : String,
  expected_sha256 : String,
  output : String,
) -> Json raise {
  let manifest : Manifest = parse(read(manifest_path, limit=4096))
  guard manifest.schema == 1 &&
    manifest.target_bytes >= 0 &&
    manifest.target_bytes <= file_limit else {
    fail("invalid manifest or target budget")
  }
  guard expected_sha256.length() == 64 &&
    manifest.target_sha256 == expected_sha256 else {
    fail("trusted target identity mismatch")
  }
  let payload = read(payload_path, limit=2 * file_limit)
  guard sha256(payload) == manifest.payload_sha256 else {
    fail("payload identity mismatch")
  }
  let result = match manifest.delivery {
    "full" => payload
    "delta" => {
      let basis = read(basis_path)
      guard sha256(basis) == manifest.basis_sha256 else {
        fail("basis identity mismatch")
      }
      @rdiff.patch(basis, payload, max_output=manifest.target_bytes)
    }
    _ => fail("unknown delivery")
  }
  guard result.length() == manifest.target_bytes &&
    sha256(result) == expected_sha256 else {
    fail("restored target identity mismatch")
  }
  // The example creates a separate cache version. Never overwrite the basis.
  save(output, result)
  {
    "verified": true,
    "output_bytes": result.length(),
    "target_sha256": sha256(result),
  }
}

///|
fn run(arguments : Array[String]) -> Json raise {
  match arguments {
    [_, _, "offer", basis, output] => offer(basis, output)
    [_, _, "build", offer, target, output] => build(offer, target, output)
    [_, _, "apply", basis, manifest, payload, expected, output] =>
      apply(basis, manifest, payload, expected, output)
    _ =>
      fail(
        "Usage: offer BASIS OFFER | build OFFER TARGET OUTPUT_DIRECTORY | apply BASIS MANIFEST PAYLOAD TRUSTED_TARGET_SHA256 NEW_CACHE",
      )
  }
}

///|
fn main {
  finish(run(@env.args()).stringify(), 0) catch {
    error => finish("Resource-cache update stopped: \{error}", 2)
  }
}
