import { describe, expect, it } from 'vitest'
import { canTeach } from '../teaching-rules'
import type { Certification, CourseType, BrevetCode } from '@/types/foundation'

// ──────────────────────── Test fixtures ────────────────────────

function cert(code: BrevetCode, overrides: Partial<Certification> = {}): Certification {
  return {
    id: `c-${code}-${Math.random()}`,
    personId: 'p-1',
    agency: 'PADI',
    category:
      code === 'EFRI' || code === 'EFR' || code === 'MEDICAL'
        ? 'additional'
        : code.startsWith('SPEC_TEACHER_')
        ? 'specialty-teacher'
        : ['DM', 'OWSI', 'IDC_STAFF', 'MI', 'CD'].includes(code as string)
        ? 'pro'
        : 'diver',
    code,
    number: '12345',
    issuedAt: '2024-01-01',
    origin: 'extern',
    createdAt: '2024-01-01T00:00:00Z',
    ...overrides,
  } as Certification
}

// Common cert sets
const dm = [cert('DM')]
const owsi = [
  cert('OWSI'),
  cert('SPEC_TEACHER_AWARE'),
  cert('SPEC_TEACHER_DEBRIS'),
  cert('SPEC_TEACHER_PPB'),
]
const idcStaff = [...owsi, cert('IDC_STAFF')]
const mi = [...idcStaff, cert('MI')]
const cd = [...mi, cert('CD')]
const noPro: Certification[] = []

// ──────────────────────── Diver courses ────────────────────────

describe('canTeach — diver courses', () => {
  const diverCourses: CourseType[] = ['OWD', 'OWD_DRY', 'AOWD', 'RESCUE', 'DSD', 'TSCHIGGI']

  it.each(diverCourses)('OWSI can teach %s', (course) => {
    expect(canTeach(owsi, course).canTeach).toBe(true)
  })

  it.each(diverCourses)('CD can teach %s', (course) => {
    expect(canTeach(cd, course).canTeach).toBe(true)
  })

  it.each(diverCourses)('DM cannot teach %s', (course) => {
    const result = canTeach(dm, course)
    expect(result.canTeach).toBe(false)
    if (!result.canTeach) {
      expect(result.reason).toMatch(/OWSI/)
    }
  })

  it.each(diverCourses)('non-pro cannot teach %s', (course) => {
    expect(canTeach(noPro, course).canTeach).toBe(false)
  })
})

// ──────────────────────── DM courses ────────────────────────

describe('canTeach — DM courses', () => {
  it('OWSI can teach DM', () => {
    expect(canTeach(owsi, 'DM').canTeach).toBe(true)
  })

  it('CD can teach DM', () => {
    expect(canTeach(cd, 'DM').canTeach).toBe(true)
  })

  it('DM cannot teach DM', () => {
    expect(canTeach(dm, 'DM').canTeach).toBe(false)
  })
})

// ──────────────────────── IDC ────────────────────────

describe('canTeach — IDC', () => {
  it('IDC Staff can teach IDC', () => {
    expect(canTeach(idcStaff, 'IDC').canTeach).toBe(true)
  })

  it('MI can teach IDC', () => {
    expect(canTeach(mi, 'IDC').canTeach).toBe(true)
  })

  it('CD can teach IDC', () => {
    expect(canTeach(cd, 'IDC').canTeach).toBe(true)
  })

  it('OWSI cannot teach IDC', () => {
    const result = canTeach(owsi, 'IDC')
    expect(result.canTeach).toBe(false)
    if (!result.canTeach) {
      expect(result.reason).toMatch(/IDC Staff/)
    }
  })
})

// ──────────────────────── IDC Staff training ────────────────────────

describe('canTeach — IDC Staff training', () => {
  it('MI can train IDC Staff', () => {
    expect(canTeach(mi, 'IDC_STAFF').canTeach).toBe(true)
  })

  it('CD can train IDC Staff', () => {
    expect(canTeach(cd, 'IDC_STAFF').canTeach).toBe(true)
  })

  it('IDC Staff cannot train IDC Staff', () => {
    const result = canTeach(idcStaff, 'IDC_STAFF')
    expect(result.canTeach).toBe(false)
    if (!result.canTeach) {
      expect(result.reason).toMatch(/MI/)
    }
  })
})

// ──────────────────────── Specialty courses ────────────────────────

describe('canTeach — Specialty', () => {
  it('OWSI auto-includes AWARE permit', () => {
    const result = canTeach(owsi, { type: 'SPECIALTY', specialty: 'AWARE' })
    expect(result.canTeach).toBe(true)
  })

  it('OWSI without NIGHT permit cannot teach NIGHT specialty', () => {
    const result = canTeach(owsi, { type: 'SPECIALTY', specialty: 'NIGHT' })
    expect(result.canTeach).toBe(false)
    if (!result.canTeach) {
      expect(result.reason).toMatch(/Permit fehlt/)
    }
  })

  it('OWSI with NIGHT permit CAN teach NIGHT specialty', () => {
    const certs = [...owsi, cert('SPEC_TEACHER_NIGHT')]
    expect(canTeach(certs, { type: 'SPECIALTY', specialty: 'NIGHT' }).canTeach).toBe(true)
  })

  it('DM with EQUIPMENT permit CAN teach EQUIPMENT (PADI exception)', () => {
    const certs = [...dm, cert('SPEC_TEACHER_EQUIPMENT')]
    expect(canTeach(certs, { type: 'SPECIALTY', specialty: 'EQUIPMENT' }).canTeach).toBe(true)
  })

  it('DM with O2 permit CAN teach O2 (PADI exception)', () => {
    const certs = [...dm, cert('SPEC_TEACHER_O2')]
    expect(canTeach(certs, { type: 'SPECIALTY', specialty: 'O2' }).canTeach).toBe(true)
  })

  it('DM without permit CANNOT teach EQUIPMENT', () => {
    expect(canTeach(dm, { type: 'SPECIALTY', specialty: 'EQUIPMENT' }).canTeach).toBe(false)
  })

  it('non-pro cannot teach specialty even with permit', () => {
    const certs = [cert('SPEC_TEACHER_NIGHT')]
    expect(canTeach(certs, { type: 'SPECIALTY', specialty: 'NIGHT' }).canTeach).toBe(false)
  })
})

// ──────────────────────── SPEI workshops ────────────────────────

describe('canTeach — SPEI', () => {
  it('CD can run any SPEI workshop', () => {
    expect(canTeach(cd, { type: 'SPEI', specialty: 'NIGHT' }).canTeach).toBe(true)
    expect(canTeach(cd, { type: 'SPEI', specialty: 'WRECK' }).canTeach).toBe(true)
  })

  it('MI cannot run SPEI', () => {
    const result = canTeach(mi, { type: 'SPEI', specialty: 'NIGHT' })
    expect(result.canTeach).toBe(false)
    if (!result.canTeach) {
      expect(result.reason).toMatch(/Course Director/)
    }
  })

  it('OWSI cannot run SPEI', () => {
    expect(canTeach(owsi, { type: 'SPEI', specialty: 'NIGHT' }).canTeach).toBe(false)
  })
})

// ──────────────────────── EFR ────────────────────────

describe('canTeach — EFR', () => {
  it('EFRI can teach EFR', () => {
    expect(canTeach([cert('EFRI')], 'EFR').canTeach).toBe(true)
    expect(canTeach([cert('EFRI')], 'EFR_REFRESHER').canTeach).toBe(true)
  })

  it('OWSI without EFRI cannot teach EFR', () => {
    expect(canTeach(owsi, 'EFR').canTeach).toBe(false)
  })

  it('CD without EFRI cannot teach EFR', () => {
    const result = canTeach(cd, 'EFR')
    expect(result.canTeach).toBe(false)
    if (!result.canTeach) {
      expect(result.reason).toMatch(/EFRI/)
    }
  })

  it('invalidated EFRI does not count', () => {
    const certs = [cert('EFRI', { invalidatedAt: '2024-06-01T00:00:00Z' })]
    expect(canTeach(certs, 'EFR').canTeach).toBe(false)
  })
})
