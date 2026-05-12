/**
 * Catalog of all PADI OWD form items that can be tracked per (course × participant).
 * Used by the Skill-Check tab and the PDF auto-fill.
 *
 * Sections:
 *  - cw_dive:      Confined Water Tauchgänge 1-5 (date + initials + PADI nr)
 *  - assessment:   Beurteilung Wasserfertigkeiten (2 items)
 *  - cw_flex:      Tauchgangsflexible Fertigkeiten CW (7 items)
 *  - kd:           Knowledge Development Teil 1-5 + Quick Review (date + quiz + video)
 *  - ow_dive:      Freiwasser-Tauchgänge 1-4 (date + initials + PADI nr)
 *  - ow_flex:      Tauchgangsflexible OW (10 items, each with "Bei TG#")
 */

export type PadiSkillSection = 'cw_dive' | 'assessment' | 'cw_flex' | 'kd' | 'ow_dive' | 'ow_flex'

export interface PadiSkillDef {
  code: string
  section: PadiSkillSection
  label_de: string
  label_en: string
  /** Should the user enter a completion date for this skill? */
  hasDate: boolean
  /** Does this skill have a Quiz checkbox? */
  hasQuiz: boolean
  /** Does this skill have a Video-Watched checkbox? */
  hasVideo: boolean
  /** Should the user pick TG# 1-4 for this OW flex skill? */
  hasTgNumber: boolean
  /** Limited range for tg_number (e.g. "TG 2,3 oder 4" for U/W-Navi and CESA) */
  tgNumberOptions?: number[]
  /** If true, this is a course-day skill (cw_dive or ow_dive). Used to derive course_day_kind. */
  courseDayKind?: 'cw1' | 'cw2' | 'cw3' | 'cw4' | 'cw5' | 'ow1' | 'ow2' | 'ow3' | 'ow4'
}

export const PADI_OWD_SKILLS: PadiSkillDef[] = [
  // ── Confined Water Tauchgänge ────────────────────────────────────────────
  { code: 'cw_1', section: 'cw_dive', label_de: 'CW Tauchgang 1', label_en: 'CW Dive 1', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false, courseDayKind: 'cw1' },
  { code: 'cw_2', section: 'cw_dive', label_de: 'CW Tauchgang 2', label_en: 'CW Dive 2', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false, courseDayKind: 'cw2' },
  { code: 'cw_3', section: 'cw_dive', label_de: 'CW Tauchgang 3', label_en: 'CW Dive 3', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false, courseDayKind: 'cw3' },
  { code: 'cw_4', section: 'cw_dive', label_de: 'CW Tauchgang 4', label_en: 'CW Dive 4', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false, courseDayKind: 'cw4' },
  { code: 'cw_5', section: 'cw_dive', label_de: 'CW Tauchgang 5', label_en: 'CW Dive 5', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false, courseDayKind: 'cw5' },

  // ── Beurteilung Wasserfertigkeiten ───────────────────────────────────────
  { code: 'assessment_swim',  section: 'assessment', label_de: '200m / 300m schwimmen', label_en: '200m / 300m swim', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false },
  { code: 'assessment_float', section: 'assessment', label_de: '10 Min Oberfläche treiben', label_en: '10 min float/tread', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false },

  // ── Tauchgangsflexible Fertigkeiten CW ───────────────────────────────────
  { code: 'cw_flex_prep_gear',       section: 'cw_flex', label_de: 'Vorbereitung und Pflege der Ausrüstung*', label_en: 'Gear preparation & care*', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false },
  { code: 'cw_flex_inflator',        section: 'cw_flex', label_de: 'Abkoppeln des Inflatorschlauchs vom Tarierjacket*', label_en: 'Disconnecting inflator hose*', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false },
  { code: 'cw_flex_band',            section: 'cw_flex', label_de: 'Lockeres Band einer Flaschenhalterung', label_en: 'Loose tank band', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false },
  { code: 'cw_flex_weight_off_surf', section: 'cw_flex', label_de: 'Ablegen und Anlegen Gewichtssystem (Oberfläche)*', label_en: 'Weight system off/on at surface*', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false },
  { code: 'cw_flex_emergency_weight',section: 'cw_flex', label_de: 'Abwerfen von Bleigewichten im Notfall*', label_en: 'Emergency weight drop*', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false },
  { code: 'cw_flex_snorkel',         section: 'cw_flex', label_de: 'Schnorcheltauchen', label_en: 'Snorkel diving', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false },
  { code: 'cw_flex_drysuit_orient',  section: 'cw_flex', label_de: 'Orientierung zum Tauchen im Trockentauchanzug', label_en: 'Dry suit orientation', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false },

  // ── Knowledge Development ────────────────────────────────────────────────
  { code: 'kd_teil_1', section: 'kd', label_de: 'Teil 1', label_en: 'Part 1', hasDate: true, hasQuiz: true, hasVideo: true, hasTgNumber: false },
  { code: 'kd_teil_2', section: 'kd', label_de: 'Teil 2', label_en: 'Part 2', hasDate: true, hasQuiz: true, hasVideo: true, hasTgNumber: false },
  { code: 'kd_teil_3', section: 'kd', label_de: 'Teil 3', label_en: 'Part 3', hasDate: true, hasQuiz: true, hasVideo: true, hasTgNumber: false },
  { code: 'kd_teil_4', section: 'kd', label_de: 'Teil 4', label_en: 'Part 4', hasDate: true, hasQuiz: true, hasVideo: true, hasTgNumber: false },
  { code: 'kd_teil_5', section: 'kd', label_de: 'Teil 5', label_en: 'Part 5', hasDate: true, hasQuiz: true, hasVideo: true, hasTgNumber: false },
  { code: 'kd_quick_review', section: 'kd', label_de: 'Quick Review (eLearning)', label_en: 'Quick Review (eLearning)', hasDate: true, hasQuiz: true, hasVideo: true, hasTgNumber: false },

  // ── Freiwasser-Tauchgänge ────────────────────────────────────────────────
  { code: 'ow_1', section: 'ow_dive', label_de: 'OW Tauchgang 1', label_en: 'OW Dive 1', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false, courseDayKind: 'ow1' },
  { code: 'ow_2', section: 'ow_dive', label_de: 'OW Tauchgang 2', label_en: 'OW Dive 2', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false, courseDayKind: 'ow2' },
  { code: 'ow_3', section: 'ow_dive', label_de: 'OW Tauchgang 3', label_en: 'OW Dive 3', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false, courseDayKind: 'ow3' },
  { code: 'ow_4', section: 'ow_dive', label_de: 'OW Tauchgang 4', label_en: 'OW Dive 4', hasDate: true, hasQuiz: false, hasVideo: false, hasTgNumber: false, courseDayKind: 'ow4' },

  // ── Tauchgangsflexible OW (10 Items, each with TG#) ──────────────────────
  { code: 'ow_flex_cramp',           section: 'ow_flex', label_de: 'Einen Krampf lösen*', label_en: 'Release a cramp*', hasDate: false, hasQuiz: false, hasVideo: false, hasTgNumber: true },
  { code: 'ow_flex_tow',             section: 'ow_flex', label_de: 'Ermüdeten Taucher schleppen/schieben*', label_en: 'Tow/push tired diver*', hasDate: false, hasQuiz: false, hasVideo: false, hasTgNumber: true },
  { code: 'ow_flex_dsmb',            section: 'ow_flex', label_de: 'Signalboje/DSMB einsetzen*', label_en: 'Use DSMB/marker buoy*', hasDate: false, hasQuiz: false, hasVideo: false, hasTgNumber: true },
  { code: 'ow_flex_compass_straight',section: 'ow_flex', label_de: 'Gerade Strecke mit Kompass*', label_en: 'Straight line w/ compass*', hasDate: false, hasQuiz: false, hasVideo: false, hasTgNumber: true },
  { code: 'ow_flex_snorkel_reg',     section: 'ow_flex', label_de: 'Wechsel Schnorchel/Lungenautomat*', label_en: 'Snorkel/regulator exchange*', hasDate: false, hasQuiz: false, hasVideo: false, hasTgNumber: true },
  { code: 'ow_flex_weight_drop',     section: 'ow_flex', label_de: 'Bleigewichte im Notfall abwerfen*', label_en: 'Emergency weight drop*', hasDate: false, hasQuiz: false, hasVideo: false, hasTgNumber: true },
  { code: 'ow_flex_scuba_off_surf',  section: 'ow_flex', label_de: 'Tauchgerät ab-/anlegen (Oberfläche)*', label_en: 'Scuba off/on at surface*', hasDate: false, hasQuiz: false, hasVideo: false, hasTgNumber: true },
  { code: 'ow_flex_weight_off_surf', section: 'ow_flex', label_de: 'Gewichtssystem ab-/anlegen (Oberfläche)*', label_en: 'Weight system off/on at surface*', hasDate: false, hasQuiz: false, hasVideo: false, hasTgNumber: true },
  { code: 'ow_flex_uw_compass',      section: 'ow_flex', label_de: 'U/W-Navigation mit Kompass (TG 2, 3 oder 4)', label_en: 'U/W navigation with compass (TG 2, 3 or 4)', hasDate: false, hasQuiz: false, hasVideo: false, hasTgNumber: true, tgNumberOptions: [2, 3, 4] },
  { code: 'ow_flex_cesa',            section: 'ow_flex', label_de: 'CESA (TG 2, 3 oder 4)', label_en: 'CESA (TG 2, 3 or 4)', hasDate: false, hasQuiz: false, hasVideo: false, hasTgNumber: true, tgNumberOptions: [2, 3, 4] },
]

export const SECTION_LABELS_DE: Record<PadiSkillSection, string> = {
  cw_dive: 'Confined Water Tauchgänge',
  assessment: 'Beurteilung der Wasserfertigkeiten',
  cw_flex: 'Tauchgangsflexible Fertigkeiten (CW)',
  kd: 'Entwicklung der Kenntnisse',
  ow_dive: 'Freiwasser-Tauchgänge',
  ow_flex: 'Tauchgangsflexible Fertigkeiten (OW)',
}
export const SECTION_LABELS_EN: Record<PadiSkillSection, string> = {
  cw_dive: 'Confined Water Dives',
  assessment: 'Water Skills Assessment',
  cw_flex: 'Flexible Skills (CW)',
  kd: 'Knowledge Development',
  ow_dive: 'Open Water Dives',
  ow_flex: 'Flexible Skills (OW)',
}
