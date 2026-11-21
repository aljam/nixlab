# Documentation link and reference audit

## Goal

Ensure that documentation remains navigable, accurate, and useful by verifying that every internal reference resolves to an existing file, anchor, module, test, or runbook.

This audit focuses on repository documentation quality. It does not validate runtime service behavior, secrets, backups, or monitoring.

## Scope

Audit every Markdown document under:

- `docs/`
- `docs/audits/`
- `docs/runbooks/`
- `docs/security/`
- Repository root documentation, where applicable

Also audit references from documentation to:

- Nix modules under `modules/`
- Host configurations under `hosts/`
- Tests under `tests/`
- Flake outputs and checks
- Public endpoint inventory files
- Other repository documentation

## Audit objective

For every documentation file, verify that:

- Relative Markdown links resolve to existing files.
- Heading anchors resolve to existing headings.
- References to Nix modules point to existing files.
- References to tests and check names point to existing definitions.
- References to runbooks, drills, and audits point to existing documents.
- Public endpoint references match the documented endpoint inventory.
- No documentation file is orphaned from the documentation index or related documentation.
- No broken, duplicated, or misleading links remain.

## Audit cadence

| Check | Minimum cadence | Owner | Evidence to retain |
|---|---|---|---|
| Documentation link check | After documentation changes | Documentation owner | Link-check result and exceptions |
| Module and test reference check | After module or test changes | Module owner | Reference-check result and exceptions |
| Documentation index review | Monthly | Documentation owner | Index coverage result and exceptions |
| Full audit review | Quarterly | Documentation and platform owners | Completed checklist, findings, and remediation plan |

## Before the audit

- [ ] Identify every Markdown documentation file in scope.
- [ ] Identify every relative link and anchor in each file.
- [ ] Identify every referenced Nix module, host, test, check, and runbook.
- [ ] Confirm the audit environment cannot modify production configuration.
- [ ] Confirm the documentation index is available for coverage review.

## Link validation

For every Markdown file:

- [ ] Extract relative links.
- [ ] Confirm each link target exists.
- [ ] Confirm each anchor target exists in the destination file.
- [ ] Confirm links use the intended relative path rather than an absolute repository path where possible.
- [ ] Confirm external links use HTTPS where applicable.
- [ ] Confirm no link exposes secrets, tokens, private keys, or sensitive service data.
- [ ] Record broken links, missing anchors, and incorrect paths as findings.

## Module and test references

For every documentation reference to repository code:

- [ ] Confirm the referenced Nix module exists.
- [ ] Confirm the referenced host configuration exists.
- [ ] Confirm the referenced test file exists.
- [ ] Confirm the referenced flake check or package name exists.
- [ ] Confirm the referenced runbook or drill exists.
- [ ] Confirm the referenced audit exists.
- [ ] Confirm the reference describes the intended behavior rather than an outdated implementation detail.
- [ ] Record missing or incorrect references as findings.

## Documentation coverage

For each major documentation area:

- [ ] Confirm the area is represented in `docs/README.md` or another intended documentation index.
- [ ] Confirm related runbooks link back to relevant recovery or security documentation.
- [ ] Confirm audits link to the procedures they validate.
- [ ] Confirm recovery documentation links to its restore drills.
- [ ] Confirm monitoring documentation links to its alert and outage runbooks.
- [ ] Confirm security documentation links to its relevant audits.
- [ ] Confirm no important documentation is unreachable from the documentation index.

## Public endpoint references

For every public endpoint reference:

- [ ] Confirm the endpoint is represented in `docs/public-endpoints.json`.
- [ ] Confirm the endpoint documentation matches the inventory.
- [ ] Confirm the endpoint has an owner, purpose, and expected availability.
- [ ] Confirm the endpoint links to the applicable public-service recovery or security documentation.
- [ ] Record missing, stale, or inconsistent endpoint references as findings.

## Findings and remediation

Classify each finding as:

- **High:** A critical runbook, recovery procedure, security control, or public endpoint is unreachable or incorrectly referenced.
- **Medium:** A documentation link, anchor, module reference, or test reference is broken or misleading.
- **Low:** Documentation organization, index coverage, or formatting needs improvement.

For every finding:

- [ ] Record the source document, link, target, and issue.
- [ ] Assign an owner and remediation deadline.
- [ ] Record the remediation plan and verification method.
- [ ] Confirm the fix resolves the link or reference.
- [ ] Confirm the corrected documentation is reviewed before merge.

## Pass criteria

The audit passes only when:

- Every in-scope relative link resolves.
- Every in-scope anchor resolves.
- Every referenced module, host, test, check, runbook, and audit exists.
- Public endpoint references match the endpoint inventory.
- Important documentation is reachable from the documentation index.
- No critical or high finding remains unowned or unremediated.
- Results, findings, and follow-up actions are recorded.

## Related documentation

- `docs/README.md`
- `docs/ARCHITECTURE.md`
- `docs/RUNBOOK.md`
- `docs/RECOVERY.md`
- `docs/SECURITY.md`
- `docs/PUBLIC_SERVICES.md`
- `docs/public-endpoints.json`
- `docs/audits/`
- `docs/runbooks/`
- `docs/security/`
