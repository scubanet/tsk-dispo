/**
 * PADI OWD Referral — AcroForm field mapping.
 *
 * Geometry analysis (page 1, PDF coordinate space, origin bottom-left):
 *
 * STUDENT BLOCK (top-left, y≈516–548):
 *   y=548  'Name Tauchschüler'            — full name
 *   y=537  'Tag'  (x=72)                  — birth day (DD)
 *   y=536  'Monat' (x=97)                 — birth month (MM)
 *   y=536  'Jahr'  (x=120)                — birth year (YYYY)
 *   y=533  'M'     (x=195, checkbox)      — gender male
 *   y=532  'W'     (x=212, checkbox)      — gender female
 *   y=516  'Postanschrift 1' (x=70)       — street
 *   y=498  'Postanschrift 2' (x=25)       — city/postal
 *   y=497  'Postanschrift 3' (x=165)      — country
 *   y=428  'EMail'           (x=49)       — student email
 *   y=470  'undefined'       (x=102, w≈22)  — small field: phone prefix/type
 *   y=470  'undefined_2'     (x=128, w≈101) — phone number (privat, by position)
 *   y=456  'undefined_3'     (x=102, w≈22)  — second phone prefix/type
 *   y=456  'undefined_4'     (x=128, w≈101) — second phone number (beruflich, by position)
 *   y=442  'undefined_5'     (x=102, w≈22)  — third phone prefix/type (unused)
 *   y=442  'undefined_6'     (x=128, w≈101) — third phone number (unused)
 *
 * 1ST INSTRUCTOR BLOCK (left side, y≈315–357):
 *   y=357  'PADI lnstructor'      (x=74, w≈155) — instructor name (note: typo 'ln' not 'In')
 *   y=343  'Unterschrift'         (x=67, w≈162) — signature (left blank)
 *   y=329  'PADI Nr'              (x=56, w≈50)  — instructor PADI pro number
 *   y=329  'Dive CenterResort Nr' (x=185, w≈43) — dive center nr
 *   y=315  'Datum'                (x=50, w≈19)  — date day
 *   y=315  'undefined_7'          (x=76, w≈19)  — date month
 *   y=315  'undefined_8'          (x=102, w≈19) — date year
 *
 * 2ND INSTRUCTOR BLOCK (y≈195–237):
 *   y=237  'PADI lnstructor_2'      — instructor name
 *   y=209  'PADI Nr_2'              — PADI pro number
 *   y=209  'Dive CenterResort Nr_2' — dive center nr
 *   y=195  'Datum_2'                — date day
 *   y=195  'undefined_13'           — date month
 *   y=195  'undefined_14'           — date year
 *   y=255  'EMail_2'                — email
 *   y=283  'undefined_9'  / y=283 'undefined_10'  — phone fields
 *   y=269  'undefined_11' / y=269 'undefined_12'  — phone fields
 *
 * 3RD INSTRUCTOR BLOCK (bottom area, y≈96):
 *   y=135  'EMail_3'
 *   y=163  'undefined_15' / 'undefined_16'
 *   y=149  'undefined_17' / 'undefined_18'
 *   (No explicit PADI lnstructor_3 / PADI Nr_3 named fields — PADI Nr_3 at y=96 is
 *    in a different sub-section at bottom center, likely a 3rd referring instructor row)
 *
 * Fields left un-mapped (filled by hand later):
 *   - CW 1–5, undefined_19–28  (Confined Water dates/initials)
 *   - Initialen 1–5, PADI Nr 1–5  (KD initials)
 *   - Teil 1–5, undefined_67–90  (Knowledge Development checkboxes)
 *   - TG Nr*, Instructor Initialen, PADINr*, Datum_3–8  (OW dive records)
 *   - Unterschrift Tauchschüler, Unterschrift Instructor, etc.
 *   - Quick Review, Schnorcheltauchen, Trockentauchanzug (optional skills)
 *   - All undefined_29–66 (skill-session checkboxes)
 */

export interface PadiReferralData {
  // Student
  studentName: string
  studentBirthTag?: string      // DD
  studentBirthMonat?: string    // MM
  studentBirthJahr?: string     // YYYY
  studentGender?: 'M' | 'W'
  studentStreet?: string
  studentCityPostal?: string
  studentCountry?: string
  studentEmail?: string
  studentPhonePrivat?: string   // phone label home/mobile → privat row
  studentPhoneBeruflich?: string // phone label work → beruflich row

  // 1st Instructor block (referring instructor)
  inst1Name?: string
  inst1PadiNr?: string
  inst1DiveCenterNr?: string
  inst1DatumTag?: string    // DD
  inst1DatumMonat?: string  // MM
  inst1DatumJahr?: string   // YYYY

  // 2nd Instructor block (second referring instructor, rarely used)
  inst2Name?: string
  inst2PadiNr?: string
  inst2DiveCenterNr?: string
  inst2Email?: string
}

/** Map data field → AcroForm field name. Text fields only (checkboxes handled separately). */
export const FIELD_MAP: Record<
  Exclude<keyof PadiReferralData, 'studentGender'>,
  string
> = {
  // Student
  studentName:         'Name Tauchschüler',
  studentBirthTag:     'Tag',
  studentBirthMonat:   'Monat',
  studentBirthJahr:    'Jahr',
  studentStreet:       'Postanschrift 1',
  studentCityPostal:   'Postanschrift 2',
  studentCountry:      'Postanschrift 3',
  studentEmail:        'EMail',
  // Phones: undefined / undefined_2 are the first two phone rows (privat / beruflich)
  // Confirmed by y-coordinates: undefined at y=470 (first row), undefined_2 at y=470 (number part)
  // We fill only the number part (the wide field), not the narrow prefix field.
  studentPhonePrivat:    'undefined_2',
  studentPhoneBeruflich: 'undefined_4',

  // Instructor block 1
  inst1Name:        'PADI lnstructor',   // note: typo in PDF — 'ln' not 'In'
  inst1PadiNr:      'PADI Nr',
  inst1DiveCenterNr: 'Dive CenterResort Nr',
  inst1DatumTag:    'Datum',
  inst1DatumMonat:  'undefined_7',
  inst1DatumJahr:   'undefined_8',

  // Instructor block 2
  inst2Name:        'PADI lnstructor_2',
  inst2PadiNr:      'PADI Nr_2',
  inst2DiveCenterNr: 'Dive CenterResort Nr_2',
  inst2Email:       'EMail_2',
}
