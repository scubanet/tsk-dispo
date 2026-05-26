import { assertEquals } from 'jsr:@std/assert@1'
import { colorForTheme, hexToRgb } from '../colors.ts'

Deno.test('colorForTheme: courseDirector preset', () => {
  assertEquals(
    colorForTheme({ preset: 'courseDirector' }),
    'rgb(34, 103, 16)',
  )
})

Deno.test('colorForTheme: seaExplorers preset', () => {
  assertEquals(
    colorForTheme({ preset: 'seaExplorers' }),
    'rgb(0, 95, 138)',
  )
})

Deno.test('colorForTheme: privat preset', () => {
  assertEquals(
    colorForTheme({ preset: 'privat' }),
    'rgb(80, 80, 80)',
  )
})

Deno.test('colorForTheme: custom with hex', () => {
  assertEquals(
    colorForTheme({ preset: 'custom', gradient_start_hex: '#FF8800' }),
    'rgb(255, 136, 0)',
  )
})

Deno.test('colorForTheme: custom without hex falls back to privat', () => {
  assertEquals(
    colorForTheme({ preset: 'custom' }),
    'rgb(80, 80, 80)',
  )
})

Deno.test('hexToRgb: lowercase + uppercase + leading hash', () => {
  assertEquals(hexToRgb('#ff0088'), { r: 255, g: 0, b: 136 })
  assertEquals(hexToRgb('FFFFFF'),  { r: 255, g: 255, b: 255 })
  assertEquals(hexToRgb('#000'),    { r: 0,   g: 0,   b: 0 })   // short form
})

Deno.test('hexToRgb: invalid returns null', () => {
  assertEquals(hexToRgb('not-hex'),  null)
  assertEquals(hexToRgb('#gg0000'),  null)
})
