/**
 * Cert-Loader: parse a .p12 (PKCS#12) bundle into { cert, privateKey }
 * for use with node-forge's PKCS#7 signing API. Also parses a separate
 * WWDR intermediate cert (Apple's CA chain).
 *
 * Secrets are passed as base64-encoded strings via Deno.env.
 */
import forge from 'node-forge'

export function base64ToBytes(b64: string): Uint8Array {
  // Validate first — atob throws on invalid base64 in some runtimes
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(b64.replace(/\s+/g, ''))) {
    throw new Error('invalid base64 string')
  }
  const bin = atob(b64.replace(/\s+/g, ''))
  const out = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i)
  return out
}

function bytesToForgeBinaryString(bytes: Uint8Array): string {
  let s = ''
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i])
  return s
}

export interface PassCertBundle {
  cert:       forge.pki.Certificate
  privateKey: forge.pki.rsa.PrivateKey
}

export function loadPassCert(p12Base64: string, password: string): PassCertBundle {
  const p12Bytes  = base64ToBytes(p12Base64)
  const p12Binary = bytesToForgeBinaryString(p12Bytes)
  const asn1      = forge.asn1.fromDer(p12Binary)
  const p12       = forge.pkcs12.pkcs12FromAsn1(asn1, password)

  // Find the cert + key bag
  const certBags = p12.getBags({ bagType: forge.pki.oids.certBag })[forge.pki.oids.certBag]
  const keyBags  = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag })[forge.pki.oids.pkcs8ShroudedKeyBag]
                || p12.getBags({ bagType: forge.pki.oids.keyBag })[forge.pki.oids.keyBag]

  if (!certBags?.length || !keyBags?.length) {
    throw new Error('p12 missing cert or key bag')
  }
  const cert = certBags[0].cert as forge.pki.Certificate
  const key  = keyBags[0].key  as forge.pki.rsa.PrivateKey
  return { cert, privateKey: key }
}

export function loadWwdrCert(cerBase64: string): forge.pki.Certificate {
  const bytes  = base64ToBytes(cerBase64)
  const binary = bytesToForgeBinaryString(bytes)
  const asn1   = forge.asn1.fromDer(binary)
  return forge.pki.certificateFromAsn1(asn1)
}
