import {
  afterEach,
  beforeEach,
  describe,
  expect,
  jest,
  test
} from '@jest/globals'
import {getInvalidLicenseChanges} from '../src/licenses'
import {getInvalidLicenseChanges as originalGetInvalidLicenseChanges} from '../src/licenses.identifier-case-baseline'
import {Change} from '../src/schemas'
import * as spdx from '../src/spdx'
import {octokitClient} from '../src/utils'

// The preparation helper copies the verified, unmodified upstream licenses.ts
// into this test-only module before patching. It removes that copy before the
// runtime build. Its imports use the unchanged upstream validity/policy bodies.
jest.mock('../src/utils', () => ({
  octokitClient: jest.fn(() => {
    throw new Error('Identifier-case fixtures must not request network access')
  })
}))

type LicenseConfig = Parameters<typeof getInvalidLicenseChanges>[1]
type InvalidChanges = Awaited<ReturnType<typeof getInvalidLicenseChanges>>

const authDeny = [
  'AGPL-1.0-only',
  'AGPL-1.0-or-later',
  'AGPL-3.0-only',
  'AGPL-3.0-or-later',
  'SSPL-1.0',
  'BUSL-1.1'
]

function change(license: string | null, name = 'case-fixture'): Change {
  return {
    change_type: 'added',
    manifest: 'package-lock.json',
    ecosystem: 'npm',
    name,
    version: '1.0.0',
    package_url: `pkg:npm/${name}@1.0.0`,
    license,
    source_repository_url: null,
    scope: 'runtime',
    vulnerabilities: [
      {
        severity: 'moderate',
        advisory_ghsa_id: 'fixture-advisory',
        advisory_summary: 'Retain the original report fields',
        advisory_url: 'https://example.invalid/fixture-advisory'
      }
    ]
  }
}

function counts(result: InvalidChanges): number[] {
  return [
    result.unlicensed.length,
    result.unresolved.length,
    result.forbidden.length
  ]
}

beforeEach(() => {
  jest.clearAllMocks()
})
afterEach(() => expect(octokitClient).not.toHaveBeenCalled())

describe('identifier-only normalization', () => {
  test.each([
    ['bsd-3-clause', 'BSD-3-Clause'],
    ['bSd-3-cLaUsE', 'BSD-3-Clause'],
    ['mit', 'MIT'],
    ['aPaChE-2.0', 'Apache-2.0'],
    ['agpl-3.0-only', 'AGPL-3.0-only'],
    ['sSpL-1.0', 'SSPL-1.0'],
    ['busl-1.1', 'BUSL-1.1'],
    ['gpl-2.0', 'GPL-2.0'],
    ['gPl-2.0+', 'GPL-2.0+'],
    ['mit OR apache-2.0', 'MIT OR Apache-2.0'],
    ['(mit AND isc) OR bsd-3-clause', '(MIT AND ISC) OR BSD-3-Clause'],
    [
      'gpl-2.0 WITH classpath-exception-2.0',
      'GPL-2.0 WITH Classpath-exception-2.0'
    ],
    ['  mit\tAND\nisc  ', '  MIT\tAND\nISC  '],
    ['BSD-3-Clause', 'BSD-3-Clause']
  ])('canonicalizes known identifiers in %j', (input, expected) => {
    expect(spdx.normalizeLicenseCase(input)).toBe(expected)
    expect(spdx.normalizeLicenseCase(expected)).toBe(expected)
  })

  test.each([
    'AND',
    'and',
    'aNd',
    'OR',
    'or',
    'oR',
    'WITH',
    'with',
    'wItH',
    'NOASSERTION',
    'noassertion',
    'NONE',
    'none',
    'OTHER',
    'other',
    'Unknown-License',
    'LicenseRef-mit',
    'LicenseRef-bsd-3-clause',
    'DocumentRef-mit:LicenseRef-bsd-3-clause',
    ''
  ])('does not invent identifier aliases for %j', input => {
    expect(spdx.normalizeLicenseCase(input)).toBe(input)
  })
})

describe('the real integration evaluates the canonical candidate', () => {
  test('allows mixed-case BSD only under the matching allow policy', async () => {
    const input = change('bSd-3-cLaUsE')
    expect(
      counts(await getInvalidLicenseChanges([input], {allow: ['BSD-3-Clause']}))
    ).toEqual([0, 0, 0])
    const denied = await getInvalidLicenseChanges([input], {allow: ['MIT']})
    expect(counts(denied)).toEqual([0, 0, 1])
    expect(denied.forbidden[0]).toBe(input)
  })

  test('denies mixed-case BSD only under the matching deny policy', async () => {
    const input = change('bsd-3-clause')
    const denied = await getInvalidLicenseChanges([input], {
      deny: ['BSD-3-Clause']
    })
    expect(counts(denied)).toEqual([0, 0, 1])
    expect(denied.forbidden[0]).toBe(input)
    expect(
      counts(await getInvalidLicenseChanges([input], {deny: ['MIT']}))
    ).toEqual([0, 0, 0])
  })

  test.each(authDeny)(
    'retains Auth deny policy for mixed-case %s',
    async license => {
      const input = change(license.toLowerCase())
      const result = await getInvalidLicenseChanges([input], {
        deny: [...authDeny]
      })
      expect(counts(result)).toEqual([0, 0, 1])
      expect(result.forbidden[0]).toBe(input)
    }
  )

  const expressions = [
    ['mit OR apache-2.0', 'MIT OR Apache-2.0'],
    ['mit AND apache-2.0', 'MIT AND Apache-2.0'],
    ['(mit AND isc) OR apache-2.0', '(MIT AND ISC) OR Apache-2.0'],
    ['agpl-3.0-only OR mit', 'AGPL-3.0-only OR MIT'],
    ['agpl-3.0-only AND mit', 'AGPL-3.0-only AND MIT'],
    [
      'gpl-2.0 WITH classpath-exception-2.0',
      'GPL-2.0 WITH Classpath-exception-2.0'
    ]
  ]
  const policies: [string, LicenseConfig][] = [
    ['allow', {allow: ['MIT', 'ISC', 'Apache-2.0']}],
    ['deny', {deny: [...authDeny]}]
  ]

  for (const [policyName, config] of policies) {
    test.each(expressions)(
      `${policyName} compound semantics match the actual canonical baseline: %s`,
      async (input, canonical) => {
        const expected = await originalGetInvalidLicenseChanges(
          [change(canonical)],
          config
        )
        expect(expected.unresolved).toEqual([])
        const actual = await getInvalidLicenseChanges([change(input)], config)
        expect(counts(actual)).toEqual(counts(expected))
      }
    )
  }
})

describe('existing special values and malformed expressions retain baseline disposition', () => {
  const unchanged: (string | null)[] = [
    null,
    'NOASSERTION',
    'noassertion',
    'NONE',
    'none',
    'OTHER',
    'other',
    'LicenseRef-custom',
    'DocumentRef-mit:LicenseRef-custom',
    'Unknown-License',
    '',
    'MIT OR',
    'MIT AND (ISC',
    'MIT && Apache-2.0',
    'mit && apache-2.0',
    'MIT or AGPL-3.0-only',
    'mit or agpl-3.0-only',
    'MIT oR AGPL-3.0-only',
    'mit oR agpl-3.0-only',
    'AGPL-3.0-only and MIT',
    'agpl-3.0-only and mit',
    'AGPL-3.0-only aNd MIT',
    'agpl-3.0-only aNd mit',
    'GPL-2.0 with Classpath-exception-2.0',
    'gpl-2.0 with classpath-exception-2.0',
    'gpl-2.0 wItH classpath-exception-2.0'
  ]
  const policies: [string, LicenseConfig][] = [
    ['allow', {allow: ['MIT', 'Apache-2.0']}],
    ['deny', {deny: [...authDeny]}]
  ]

  for (const [policyName, config] of policies) {
    test.each(unchanged)(
      `${policyName} preserves baseline result for %j`,
      async license => {
        const input = change(license)
        const original = JSON.stringify(input)
        const expected = await originalGetInvalidLicenseChanges([input], config)
        const actual = await getInvalidLicenseChanges([input], config)
        // In particular, normalization must not turn a parser disagreement on
        // lowercase/mixed-case operators into an accepted deny-mode candidate.
        expect(actual).toEqual(expected)
        expect(JSON.stringify(input)).toBe(original)
      }
    )
  }
})

test('canonical cache keys retain both original forbidden report objects', async () => {
  const changes = [
    change('agpl-3.0-only', 'lower'),
    change('AGPL-3.0-only', 'canonical'),
    change('AgPl-3.0-OnLy', 'mixed')
  ]
  const original = JSON.stringify(changes)
  const config = {deny: [...authDeny]}
  const policyBytes = JSON.stringify(config)
  const result = await getInvalidLicenseChanges(changes, config)
  expect(counts(result)).toEqual([0, 0, 3])
  for (const [index, input] of changes.entries()) {
    expect(result.forbidden[index]).toBe(input)
  }
  expect(JSON.stringify(changes)).toBe(original)
  expect(JSON.stringify(config)).toBe(policyBytes)
})

test.each<LicenseConfig>([{allow: ['mIt']}, {deny: ['agpl-3.0-only']}])(
  'does not normalize user policy configuration: %j',
  async config => {
    const changes = [change('MIT'), change('AGPL-3.0-only')]
    const policyBytes = JSON.stringify(config)
    const expected = await originalGetInvalidLicenseChanges(changes, config)
    expect(await getInvalidLicenseChanges(changes, config)).toEqual(expected)
    expect(JSON.stringify(config)).toBe(policyBytes)
  }
)

test('preserves original unlicensed, unresolved and forbidden report categories', async () => {
  const changes = [
    change(null),
    change('NOASSERTION'),
    change('Unknown-License'),
    change('agpl-3.0-only')
  ]
  const original = JSON.stringify(changes)
  const result = await getInvalidLicenseChanges(changes, {deny: [...authDeny]})
  expect(result.unlicensed).toEqual([changes[0], changes[1]])
  expect(result.unresolved).toEqual([changes[2]])
  expect(result.forbidden).toEqual([changes[3]])
  expect(JSON.stringify(changes)).toBe(original)
})

test('retains existing removed-change and explicit exclusion behavior', async () => {
  const removed = {
    ...change('agpl-3.0-only', 'removed'),
    change_type: 'removed' as const
  }
  const excluded = change('agpl-3.0-only', 'already-excluded')
  const config = {
    deny: [...authDeny],
    licenseExclusions: ['pkg:npm/already-excluded@1.0.0']
  }
  const policyBytes = JSON.stringify(config)
  const expected = await originalGetInvalidLicenseChanges(
    [removed, excluded],
    config
  )
  expect(await getInvalidLicenseChanges([removed, excluded], config)).toEqual(
    expected
  )
  expect(counts(expected)).toEqual([0, 0, 0])
  expect(JSON.stringify(config)).toBe(policyBytes)
})
