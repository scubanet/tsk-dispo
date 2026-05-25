/**
 * PKCS#7 detached signature of manifest.json using the Pass Type ID
 * certificate + Apple WWDR intermediate, as required by Apple Wallet.
 *
 * Output: DER-encoded PKCS#7 message (binary) — written to `signature`
 * file inside the .pkpass bundle.
 */
import forge from 'node-forge'
import type { PassCertBundle } from './certs.ts'

export function signManifest(
  manifestBytes: Uint8Array,
  pass:          PassCertBundle,
  wwdr:          forge.pki.Certificate,
): Uint8Array {
  const p7 = forge.pkcs7.createSignedData()

  // Convert manifest to forge's binary string format
  let manifestBinary = ''
  for (let i = 0; i < manifestBytes.length; i++) {
    manifestBinary += String.fromCharCode(manifestBytes[i])
  }
  p7.content = forge.util.createBuffer(manifestBinary, 'binary')

  p7.addCertificate(pass.cert)
  p7.addCertificate(wwdr)

  p7.addSigner({
    key:           pass.privateKey,
    certificate:   pass.cert,
    digestAlgorithm: forge.pki.oids.sha256,
    authenticatedAttributes: [
      { type: forge.pki.oids.contentType,   value: forge.pki.oids.data },
      { type: forge.pki.oids.messageDigest /* SHA-256 of content set automatically */ },
      { type: forge.pki.oids.signingTime,   value: new Date() },
    ],
  })

  // Detached signature — content is NOT included, just the message digest
  p7.sign({ detached: true })

  const derBytes = forge.asn1.toDer(p7.toAsn1()).getBytes()
  const out = new Uint8Array(derBytes.length)
  for (let i = 0; i < derBytes.length; i++) out[i] = derBytes.charCodeAt(i)
  return out
}
