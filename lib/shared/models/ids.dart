// ─────────────────────────────────────────────────────────────────────────────
// IDS
//
// Every id in PARQX is a Postgres bigint. The API sends them as JSON numbers, and
// as strings once a value is beyond what JavaScript holds exactly — the backend
// deliberately keeps those as strings rather than rounding them. Dart's int is
// 64-bit, so both forms fit.
//
// The models used to read ids as `(json['id'] as num?)?.toInt() ?? 0`. A string id
// threw a cast error, and a missing one quietly became 0: a booking with id 0 then
// fails every later call — pay, cancel, refresh — somewhere far from the cause.
// A missing or malformed id is now an error at the point it arrives.
// ─────────────────────────────────────────────────────────────────────────────

/// Reads a required id. Throws [FormatException] rather than returning 0.
int parseId(Object? raw, String field) {
  final id = parseOptionalId(raw, field);
  if (id == null) throw FormatException('Missing id "$field"');
  return id;
}

/// Reads an id that may legitimately be absent. Present but malformed still throws.
int? parseOptionalId(Object? raw, String field) {
  if (raw == null) return null;
  final int? value = switch (raw) {
    int() => raw,
    double() when raw.isFinite && raw == raw.truncateToDouble() => raw.toInt(),
    String() => int.tryParse(raw.trim()),
    _ => null,
  };
  if (value == null || value <= 0) {
    throw FormatException('Invalid id "$field": $raw');
  }
  return value;
}
