# Read decimal bytes from `gzip -dc archive | od -An -v -tu1`.
# Inspect actual headers: bsdtar listing hides AppleDouble members by default.
function reject(message) {
  print "bundle archive: " message > "/dev/stderr"
  failed = 1
  exit 1
}
function header(    i, nonzero, name, prefix, size, digit, magic) {
  nonzero = 0
  for (i = 1; i <= 512; i++) if (bytes[i] != 0) nonzero = 1
  if (!nonzero) return
  if (bytes[157] != 0 && bytes[157] != 48) reject("non-regular or extended metadata header")
  name = ""
  for (i = 1; i <= 100 && bytes[i] != 0; i++) name = name sprintf("%c", bytes[i])
  prefix = ""
  for (i = 346; i <= 500 && bytes[i] != 0; i++) prefix = prefix sprintf("%c", bytes[i])
  if (prefix != "") name = prefix "/" name
  if (name ~ /(^|\/)\._/) reject("AppleDouble member " name)
  for (i = 109; i <= 124; i++) {
    if (bytes[i] != 0 && bytes[i] != 32 && bytes[i] != 48) reject("machine-specific uid or gid")
  }
  for (i = 266; i <= 329; i++) if (bytes[i] != 0) reject("machine-specific owner or group name")
  magic = ""
  for (i = 258; i <= 262; i++) magic = magic sprintf("%c", bytes[i])
  if (magic != "ustar") reject("archive is not portable ustar")
  size = 0
  for (i = 125; i <= 136; i++) {
    digit = bytes[i]
    if (digit == 0 || digit == 32) continue
    if (digit < 48 || digit > 55) reject("non-octal member size")
    size = size * 8 + digit - 48
  }
  remaining = int((size + 511) / 512)
  members++
}
{
  for (field = 1; field <= NF; field++) {
    bytes[++offset] = $field
    if (offset == 512) {
      if (remaining > 0) remaining--
      else header()
      offset = 0
    }
  }
}
END {
  if (failed) exit 1
  if (offset != 0 || remaining != 0 || members == 0) reject("incomplete or empty archive")
}
