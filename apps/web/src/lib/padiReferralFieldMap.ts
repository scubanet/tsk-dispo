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
 * CONFINED WATER (CW 1–5), left-center block (y≈493–537):
 *   Each row: CW N (Tag, x=259), undefined_19/21/23/25/27 (Monat, x=289),
 *             undefined_20/22/24/26/28 (Jahr, x=318), Initialen N (x=349), PADI Nr N (x=387)
 *   CW 1: y=537  CW 1, undefined_19, undefined_20, Initialen 1, PADI Nr 1
 *   CW 2: y=526  CW 2, undefined_21, undefined_22, Initialen 2, PADI Nr 2
 *   CW 3: y=515  CW 3, undefined_23, undefined_24, Initialen 3, PADI Nr 3
 *   CW 4: y=504  CW 4, undefined_25, undefined_26, Initialen 4, PADI Nr 4
 *   CW 5: y=493  CW 5, undefined_27, undefined_28, Initialen 5, PADI Nr 5
 *
 * KNOWLEDGE DEVELOPMENT (Teil 1–5), right block (y≈496–540):
 *   Each row: Teil N (Tag, x=483), undefined_67/71/75/79/83 (Monat, x=512),
 *             undefined_68/72/76/80/84 (Jahr, x=542),
 *             undefined_69/73/77/81/85 (x=611, skipped — likely a label/note column),
 *             undefined_70/74/78/82/86 (Initialen, x=688),
 *             PADI Nr N_2 (PADI Nr, x=726)
 *   KD 1: y=540  Teil 1, undefined_67, undefined_68, undefined_69, undefined_70, PADI Nr 1_2
 *   KD 2: y=529  Teil 2, undefined_71, undefined_72, undefined_73, undefined_74, PADI Nr 2_2
 *   KD 3: y=518  Teil 3, undefined_75, undefined_76, undefined_77, undefined_78, PADI Nr 3_2
 *   KD 4: y=507  Teil 4, undefined_79, undefined_80, undefined_81, undefined_82, PADI Nr 4_2
 *   KD 5: y=496  Teil 5, undefined_83, undefined_84, undefined_85, undefined_86, PADI Nr 5_2
 *   Quick Review: y=480  Quick Review (Tag), undefined_87 (Monat), undefined_88 (Jahr),
 *                        undefined_89 (x=611, skip), undefined_90 (Initialen, x=688),
 *                        'Anmerkung...' (PADI Nr, x=726 — long label name, skip filling)
 *   Note: No separate Quiz/Video checkbox fields found — all fields in the row are /Tx text.
 *         The x=611 column appears to be a non-fillable label/note column — leave unmapped.
 *
 * OPEN WATER DIVES (TG Nr1–4), right-center block (y≈383–396):
 *   OW1 (y=396): TG Nr1 (Tag, x=462), undefined_93 (Monat, x=489), undefined_94 (Jahr, x=515),
 *                Initialen (x=538), Nr (PADINr, x=573)
 *   OW2 (y=383): TG Nr2 (Tag, x=462), undefined_97 (Monat, x=489), undefined_98 (Jahr, x=515),
 *                'Tauchgangsflexible...' (x=538, label — skip), Nr_2 (PADINr, x=573)
 *   OW3 (y=396): TG Nr3 (Tag, x=628), undefined_95 (Monat, x=655), undefined_96 (Jahr, x=681),
 *                Initialen 1_2 (x=704), PADINr 1 (x=730)
 *   OW4 (y=383): TG Nr4 (Tag, x=628), undefined_99 (Monat, x=655), undefined_100 (Jahr, x=681),
 *                Initialen 2_2 (x=704), PADINr 2 (x=730)
 *   Note: OW1 Initialen = 'Initialen' (no suffix); OW2 Initialen field name is a long label string
 *         — OW2 Initialen left unmapped (field name is the full tooltip text, unreliable to fill).
 *         OW1 PADINr = 'Nr'; OW2 PADINr = 'Nr_2'.
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
  // Split phone fields (prefix = country code without +, number = rest)
  studentPhonePrivatPrefix?: string   // e.g. "41"
  studentPhonePrivatNumber?: string   // e.g. "79 877 80 80"
  studentPhoneBeruflichPrefix?: string
  studentPhoneBeruflichNumber?: string

  // 1st Instructor block (referring instructor)
  inst1Name?: string
  inst1PadiNr?: string
  inst1DiveCenterNr?: string
  inst1DatumTag?: string    // DD
  inst1DatumMonat?: string  // MM
  inst1DatumJahr?: string   // YYYY
  inst1Email?: string
  inst1PhonePrefix?: string
  inst1PhoneNumber?: string

  // 2nd Instructor block (second referring instructor, rarely used)
  inst2Name?: string
  inst2PadiNr?: string
  inst2DiveCenterNr?: string
  inst2Email?: string
  inst2PhonePrefix?: string
  inst2PhoneNumber?: string

  // Confined Water (CW 1–5) — pool days
  cw1Tag?: string; cw1Monat?: string; cw1Jahr?: string; cw1Initialen?: string; cw1PadiNr?: string
  cw2Tag?: string; cw2Monat?: string; cw2Jahr?: string; cw2Initialen?: string; cw2PadiNr?: string
  cw3Tag?: string; cw3Monat?: string; cw3Jahr?: string; cw3Initialen?: string; cw3PadiNr?: string
  cw4Tag?: string; cw4Monat?: string; cw4Jahr?: string; cw4Initialen?: string; cw4PadiNr?: string
  cw5Tag?: string; cw5Monat?: string; cw5Jahr?: string; cw5Initialen?: string; cw5PadiNr?: string

  // Knowledge Development (KD Teil 1–5) — theory days
  // Note: Quiz/Video columns are /Tx text fields in the PDF (not checkboxes).
  //       They live at x=611 (undefined_69/73/77/81/85) — left unmapped (label column).
  kd1Tag?: string; kd1Monat?: string; kd1Jahr?: string; kd1Initialen?: string; kd1PadiNr?: string
  kd2Tag?: string; kd2Monat?: string; kd2Jahr?: string; kd2Initialen?: string; kd2PadiNr?: string
  kd3Tag?: string; kd3Monat?: string; kd3Jahr?: string; kd3Initialen?: string; kd3PadiNr?: string
  kd4Tag?: string; kd4Monat?: string; kd4Jahr?: string; kd4Initialen?: string; kd4PadiNr?: string
  kd5Tag?: string; kd5Monat?: string; kd5Jahr?: string; kd5Initialen?: string; kd5PadiNr?: string

  // Open Water dives (OW 1–4) — see days
  // OW1+OW2 share the left pair; OW3+OW4 share the right pair.
  // OW2 Initialen field name is a long label text — left unmapped.
  ow1Tag?: string; ow1Monat?: string; ow1Jahr?: string; ow1Initialen?: string; ow1PadiNr?: string
  ow2Tag?: string; ow2Monat?: string; ow2Jahr?: string; ow2PadiNr?: string  // no ow2Initialen (unmapped)
  ow3Tag?: string; ow3Monat?: string; ow3Jahr?: string; ow3Initialen?: string; ow3PadiNr?: string
  ow4Tag?: string; ow4Monat?: string; ow4Jahr?: string; ow4Initialen?: string; ow4PadiNr?: string
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
  // Split phone fields — narrow column (prefix) + wide column (number)
  // y=470: 'undefined' (x≈102, w≈22, prefix) + 'undefined_2' (x≈128, w≈101, number) → privat
  // y=456: 'undefined_3' (x≈102, w≈22, prefix) + 'undefined_4' (x≈128, w≈101, number) → beruflich
  studentPhonePrivatPrefix:    'undefined',
  studentPhonePrivatNumber:    'undefined_2',
  studentPhoneBeruflichPrefix: 'undefined_3',
  studentPhoneBeruflichNumber: 'undefined_4',

  // Instructor block 1
  inst1Name:        'PADI lnstructor',   // note: typo in PDF — 'ln' not 'In'
  inst1PadiNr:      'PADI Nr',
  inst1DiveCenterNr: 'Dive CenterResort Nr',
  inst1DatumTag:    'Datum',
  inst1DatumMonat:  'undefined_7',
  inst1DatumJahr:   'undefined_8',
  // Inst1 phone: y≈283 'undefined_9' (prefix, narrow) + 'undefined_10' (number, wide)
  inst1Email:       'EMail_2',
  inst1PhonePrefix: 'undefined_9',
  inst1PhoneNumber: 'undefined_10',

  // Instructor block 2
  inst2Name:        'PADI lnstructor_2',
  inst2PadiNr:      'PADI Nr_2',
  inst2DiveCenterNr: 'Dive CenterResort Nr_2',
  inst2Email:       'EMail_3',
  // Inst2 phone: y≈163 'undefined_15' (prefix, narrow) + 'undefined_16' (number, wide)
  inst2PhonePrefix: 'undefined_15',
  inst2PhoneNumber: 'undefined_16',

  // Confined Water (CW 1–5) — pool days
  // Layout per row: Tag | Monat (undefined_odd) | Jahr (undefined_even) | Initialen N | PADI Nr N
  cw1Tag:      'CW 1',
  cw1Monat:    'undefined_19',
  cw1Jahr:     'undefined_20',
  cw1Initialen: 'Initialen 1',
  cw1PadiNr:   'PADI Nr 1',

  cw2Tag:      'CW 2',
  cw2Monat:    'undefined_21',
  cw2Jahr:     'undefined_22',
  cw2Initialen: 'Initialen 2',
  cw2PadiNr:   'PADI Nr 2',

  cw3Tag:      'CW 3',
  cw3Monat:    'undefined_23',
  cw3Jahr:     'undefined_24',
  cw3Initialen: 'Initialen 3',
  cw3PadiNr:   'PADI Nr 3',

  cw4Tag:      'CW 4',
  cw4Monat:    'undefined_25',
  cw4Jahr:     'undefined_26',
  cw4Initialen: 'Initialen 4',
  cw4PadiNr:   'PADI Nr 4',

  cw5Tag:      'CW 5',
  cw5Monat:    'undefined_27',
  cw5Jahr:     'undefined_28',
  cw5Initialen: 'Initialen 5',
  cw5PadiNr:   'PADI Nr 5',

  // Knowledge Development (KD Teil 1–5) — theory days
  // Layout per row: Tag (Teil N) | Monat | Jahr | [x=611 col — unmapped] | Initialen (x=688) | PADI Nr N_2
  kd1Tag:      'Teil 1',
  kd1Monat:    'undefined_67',
  kd1Jahr:     'undefined_68',
  kd1Initialen: 'undefined_70',   // x=688, Initialen column
  kd1PadiNr:   'PADI Nr 1_2',

  kd2Tag:      'Teil 2',
  kd2Monat:    'undefined_71',
  kd2Jahr:     'undefined_72',
  kd2Initialen: 'undefined_74',
  kd2PadiNr:   'PADI Nr 2_2',

  kd3Tag:      'Teil 3',
  kd3Monat:    'undefined_75',
  kd3Jahr:     'undefined_76',
  kd3Initialen: 'undefined_78',
  kd3PadiNr:   'PADI Nr 3_2',

  kd4Tag:      'Teil 4',
  kd4Monat:    'undefined_79',
  kd4Jahr:     'undefined_80',
  kd4Initialen: 'undefined_82',
  kd4PadiNr:   'PADI Nr 4_2',

  kd5Tag:      'Teil 5',
  kd5Monat:    'undefined_83',
  kd5Jahr:     'undefined_84',
  kd5Initialen: 'undefined_86',
  kd5PadiNr:   'PADI Nr 5_2',

  // Open Water dives (OW 1–4) — see days
  // OW1 (y=396, left pair): TG Nr1 | undefined_93 | undefined_94 | Initialen | Nr
  ow1Tag:      'TG Nr1',
  ow1Monat:    'undefined_93',
  ow1Jahr:     'undefined_94',
  ow1Initialen: 'Initialen',
  ow1PadiNr:   'Nr',

  // OW2 (y=383, left pair): TG Nr2 | undefined_97 | undefined_98 | [label field — skip] | Nr_2
  ow2Tag:      'TG Nr2',
  ow2Monat:    'undefined_97',
  ow2Jahr:     'undefined_98',
  ow2PadiNr:   'Nr_2',

  // OW3 (y=396, right pair): TG Nr3 | undefined_95 | undefined_96 | Initialen 1_2 | PADINr 1
  ow3Tag:      'TG Nr3',
  ow3Monat:    'undefined_95',
  ow3Jahr:     'undefined_96',
  ow3Initialen: 'Initialen 1_2',
  ow3PadiNr:   'PADINr 1',

  // OW4 (y=383, right pair): TG Nr4 | undefined_99 | undefined_100 | Initialen 2_2 | PADINr 2
  ow4Tag:      'TG Nr4',
  ow4Monat:    'undefined_99',
  ow4Jahr:     'undefined_100',
  ow4Initialen: 'Initialen 2_2',
  ow4PadiNr:   'PADINr 2',
}
