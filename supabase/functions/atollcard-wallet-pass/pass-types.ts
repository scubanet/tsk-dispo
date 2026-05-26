/**
 * Apple Wallet Pass Format types — minimal subset for the generic
 * pass style. Full spec: developer.apple.com/library/archive/documentation/
 * UserExperience/Reference/PassKit_Bundle/Chapters/Lower-Level.html
 */

export interface PassField {
  key: string
  label?: string
  value: string | number
  textAlignment?: 'PKTextAlignmentLeft' | 'PKTextAlignmentCenter' | 'PKTextAlignmentRight' | 'PKTextAlignmentNatural'
}

export interface PassStructure {
  headerFields?:    PassField[]   // max 3
  primaryFields?:   PassField[]   // max 1 in generic
  secondaryFields?: PassField[]   // max 4
  auxiliaryFields?: PassField[]   // max 4
  backFields?:      PassField[]   // unlimited
}

export interface PassBarcode {
  format:           'PKBarcodeFormatQR' | 'PKBarcodeFormatPDF417' | 'PKBarcodeFormatAztec' | 'PKBarcodeFormatCode128'
  message:          string
  messageEncoding:  string         // 'iso-8859-1' for QR
  altText?:         string
}

export interface PassJson {
  formatVersion:      1
  passTypeIdentifier: string
  serialNumber:       string
  teamIdentifier:     string
  organizationName:   string
  description:        string
  logoText?:          string
  backgroundColor?:   string       // "rgb(r, g, b)"
  foregroundColor?:   string
  labelColor?:        string       // "rgba(r, g, b, a)"
  generic?:           PassStructure
  barcodes?:          PassBarcode[]
}

/**
 * Subset of card+contact data we need from DB to render a pass.
 * Comes from a SELECT join in Phase C.
 */
export interface CardData {
  id:           string
  slug:         string
  title:        string
  subtitle:     string | null
  badge:        string | null
  theme:        {
    preset: 'courseDirector' | 'seaExplorers' | 'privat' | 'custom'
    gradient_start_hex?: string | null
    gradient_end_hex?:   string | null
  }
  dive_profile: {
    padi_member_number?: string | null
    instructor_level?:   string | null
    total_dives?:        number | null
    since_year?:         number | null
    specialties?:        string[]
    teaching_languages?: string[]
  } | null
  updated_at:   string  // ISO timestamp
  public_url:   string  // 'https://atoll-os.com/c/<slug>'
}

export interface ContactData {
  display_name:   string
  primary_email?: string | null
  primary_phone?: string | null
}
