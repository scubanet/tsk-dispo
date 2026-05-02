import { useEffect, useMemo, useState } from 'react'
import clsx from 'clsx'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'

interface Skill {
  id: string
  code: string
  label: string
  category: string | null
}

interface Inst {
  id: string
  name: string
  padi_level: string
}

export function SkillMatrixScreen() {
  const [skills, setSkills] = useState<Skill[]>([])
  const [instructors, setInstructors] = useState<Inst[]>([])
  const [matrix, setMatrix] = useState<Set<string>>(new Set())
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState<string>('all')

  useEffect(() => {
    Promise.all([
      supabase.from('skills').select('id, code, label, category').order('label'),
      supabase.from('instructors').select('id, name, padi_level').eq('active', true).order('last_name').order('first_name'),
      supabase.from('instructor_skills').select('instructor_id, skill_id'),
    ]).then(([s, i, m]) => {
      setSkills((s.data ?? []) as Skill[])
      setInstructors((i.data ?? []) as Inst[])
      setMatrix(new Set((m.data ?? []).map((r: any) => `${r.instructor_id}|${r.skill_id}`)))
    })
  }, [])

  const categories = useMemo(() => {
    const set = new Set<string>()
    skills.forEach((s) => s.category && set.add(s.category))
    return ['all', ...Array.from(set).sort()]
  }, [skills])

  const filteredSkills = useMemo(() => {
    if (category === 'all') return skills
    return skills.filter((s) => s.category === category)
  }, [skills, category])

  const filteredInstructors = useMemo(() => {
    if (!search) return instructors
    return instructors.filter((i) => i.name.toLowerCase().includes(search.toLowerCase()))
  }, [instructors, search])

  async function toggle(instId: string, skillId: string) {
    const key = `${instId}|${skillId}`
    if (matrix.has(key)) {
      await supabase
        .from('instructor_skills')
        .delete()
        .match({ instructor_id: instId, skill_id: skillId })
      const next = new Set(matrix)
      next.delete(key)
      setMatrix(next)
    } else {
      await supabase
        .from('instructor_skills')
        .insert({ instructor_id: instId, skill_id: skillId })
      const next = new Set(matrix)
      next.add(key)
      setMatrix(next)
    }
  }

  return (
    <>
      <Topbar title="Skill-Matrix" subtitle={`${instructors.length} Personen × ${skills.length} Skills`}>
        <div className="search" style={{ width: 200 }}>
          <Icon name="search" size={14} />
          <input
            placeholder="Person suchen…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <select
          value={category}
          onChange={(e) => setCategory(e.target.value)}
          style={{ padding: '6px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)' }}
        >
          {categories.map((c) => (
            <option key={c} value={c}>{c === 'all' ? 'Alle Kategorien' : c}</option>
          ))}
        </select>
      </Topbar>

      <div className="scroll" style={{ flex: 1, padding: 16, overflow: 'auto' }}>
        <div className="glass card" style={{ padding: 0, overflow: 'auto' }}>
          <table style={{ borderCollapse: 'collapse', fontSize: 12 }}>
            <thead>
              <tr>
                <th
                  style={{
                    position: 'sticky',
                    left: 0,
                    top: 0,
                    background: 'var(--surface-strong)',
                    backdropFilter: 'blur(20px)',
                    textAlign: 'left',
                    padding: 8,
                    minWidth: 200,
                    zIndex: 2,
                  }}
                >
                  Person
                </th>
                {filteredSkills.map((s) => (
                  <th
                    key={s.id}
                    style={{
                      padding: '8px 4px',
                      writingMode: 'vertical-rl',
                      whiteSpace: 'nowrap',
                      verticalAlign: 'bottom',
                      height: 140,
                      fontWeight: 500,
                      fontSize: 11,
                      background: 'var(--surface-strong)',
                      backdropFilter: 'blur(20px)',
                      position: 'sticky',
                      top: 0,
                      zIndex: 1,
                    }}
                  >
                    {s.label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filteredInstructors.map((i) => (
                <tr key={i.id}>
                  <td
                    style={{
                      position: 'sticky',
                      left: 0,
                      background: 'var(--surface-strong)',
                      backdropFilter: 'blur(20px)',
                      padding: 8,
                      fontWeight: 500,
                      fontSize: 12,
                      borderTop: '0.5px solid var(--separator)',
                    }}
                  >
                    {i.name}
                    <div className="caption-2">{i.padi_level}</div>
                  </td>
                  {filteredSkills.map((s) => {
                    const has = matrix.has(`${i.id}|${s.id}`)
                    return (
                      <td
                        key={s.id}
                        onClick={() => toggle(i.id, s.id)}
                        className={clsx(has && 'has')}
                        style={{
                          textAlign: 'center',
                          padding: 6,
                          cursor: 'pointer',
                          background: has ? 'var(--accent-soft)' : undefined,
                          color: has ? 'var(--accent)' : 'var(--ink-4)',
                          fontWeight: has ? 700 : 400,
                          borderTop: '0.5px solid var(--separator)',
                        }}
                      >
                        {has ? '✓' : '·'}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}
