# Dependency review SPDX identifier casing

The pinned `actions/dependency-review-action` v5.0.0 source treats known SPDX
license identifiers with different casing as unresolved. GitHub's Pub snapshots
can supply these identifiers in lowercase. SPDX 2.3.1 [section D.2](https://spdx.github.io/spdx-spec/v2.3.1/SPDX-license-expressions/)
defines identifiers as case-insensitive and operators as case-sensitive.

This preparation keeps the existing required Dependency Review job and its
policy inputs. It builds a narrowly corrected action from the official commit
`a1d282b36b6f3519aa1f3fc636f609c47dddb294`. It does not change dependency
snapshots, severities, denied licenses, existing package exclusions, retry
settings, action metadata, permissions, or the candidate dependency graph.

## Correction

`identifier-case.patch` changes two source files. The local candidate license
expression is normalized once before validity and policy evaluation. Only
known identifiers from the official lockfile's existing `spdx-license-ids`
3.0.23 and `spdx-exceptions` 2.3.0 tables are mapped to their canonical spelling.
The tables, patch, source preimages and resulting source have exact hash guards.
No dependency is added or upgraded.

Operators, custom references, unknown tokens and special values remain
unchanged. If an expression contains an incorrectly cased operator, the whole
expression remains unchanged: the upstream parsers disagree on those inputs,
so correcting their identifiers alone could alter the original policy result.
Existing validity and policy functions are unchanged. The validity cache uses
the canonical local expression; original change objects and report fields keep
the exact incoming metadata.

## Immutable preparation and execution

The workflow checks out a separately reviewed preparation commit by its full
SHA and the official action by its full SHA. It does not execute a helper from
the candidate checkout. Fixed reserved paths must be absent, including dangling
symlinks, before the trusted checkouts. The official action checkout must be a
fresh ordinary Git checkout with all 77 tracked files and modes matching the
pinned tree. Extra files, nested Git metadata and symlinked inputs are rejected.

Node 24.22.1 is selected before the candidate checkout, with setup-node's
automatic package-manager caching disabled. The helper requires its bundled
npm 11.19.1 and runs in isolated Python mode. Every npm command has an explicit
CLI prefix and disables workspace discovery. Empty private npm configurations,
a private cache and a newly constructed child environment prevent candidate
workspace configuration, hooks and credentials from influencing the build.
Existing credential-free host proxy transport and an external public host CA
may be retained without disabling TLS verification.

The helper installs the unchanged lockfile with lifecycle scripts disabled,
runs the preparation and policy regressions, then builds TypeScript and the
real `ncc` distribution. All four output files must match their admitted
hashes. The original official `action.yml` then runs from that prepared
directory, in the original workspace and with the original inputs. All new
steps apply only to the same pull-request event on which the existing action
runs. The runner action cache is never modified.

The full helper commit must remain reachable while the workflow references it.
Publication retains an ordinary reviewed branch or merge ancestry containing
that commit; the workflow itself always uses the immutable SHA, with no
branch-based fallback.

## Regression evidence

The unchanged baseline distribution was rebuilt using Node 24.22.1 and npm
11.19.1. All four files matched the official distribution byte for byte. The
corrected build changes the normalization call, normalizer and generated
identifier table; dependency source contents, license notices and the source
map registration helper remain unchanged.

The preparation executes:

- 15 source, path, process and loader isolation tests, including a real hostile
  ancestor npm workspace with a benign marker proving whether its hooks run.
- All 190 original upstream Jest cases plus 111 identifier and policy
  regression cases. The public HTTPS fixtures retain their assertions and
  receive a 20-second per-case deadline.
- The upstream formatting, lint, TypeScript and `ncc` build commands.
- Eight loopback-only tests of the actual built action entrypoint. These cover
  the 24 observed lowercase Pub license rows, forbidden case variants,
  malformed and unknown expressions, existing special/custom categories and
  exclusions, and the moderate vulnerability threshold. They use synthetic
  responses and a dummy fixture token, with no live GitHub mutation or
  replacement of the subsequent real dependency review.

The local `--offline-cache` option permits reproducing the same locked build
from an already populated owned package cache. The workflow uses a fresh cache.
The exact prepared action still has to pass the normal required job against
the actual pull-request dependency comparison.
