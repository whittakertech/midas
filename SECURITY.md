---
versions: {}
---

# Security Policy

WhittakerTech takes the security of its software seriously. This file is the
canonical statement of which versions of Midas (`whittaker_tech-midas`) receive
security and bug fixes, and how to report a vulnerability.

The YAML frontmatter above is machine-readable (it is consumed by
WhittakerTech tooling); the sections below are the human-readable form of the
same information. Keep them in agreement.

## Supported Versions

Support levels: `full` (bug fixes and security fixes), `security` (security
fixes only), `none` (no further fixes or support).

| Version line | Support | End of support |
|--------------|---------|----------------|
| _None declared_ | _Pending, see "Decisions pending"_ | n/a |

Midas follows [Semantic Versioning](https://semver.org/) (see `CHANGELOG.md`).
Published releases to date are 0.1.0, 0.1.1, 0.2.0, 0.3.0, 0.4.0, 0.4.1 and
0.5.0. No support or end-of-life policy for any of them has been formally
adopted, so none is declared here. Ruby and Rails compatibility ranges (see the
gemspec) are not a statement of version support.

### Decisions pending

The maintainer has not yet decided which Midas version lines receive fixes, so
the `versions` mapping in the frontmatter is intentionally empty. Do not read
the absence of a line as either support or end-of-life. REQUIRING LEE'S
DECISION: which 0.x lines (for example 0.5.x only, or 0.4.x as well) are
supported, at what level, and whether any end-of-support dates apply.

## Reporting a Vulnerability

**Status: reporting channel pending (REQUIRING LEE'S DECISION).**
GitHub private vulnerability reporting is not currently enabled for this
repository, and no dedicated security contact has been established. Until one
is published here, please do not disclose vulnerabilities in public issues or
pull requests. Contact the maintainers through the
[WhittakerTech organization](https://github.com/whittakertech) by a non-public
route, without including exploit details in any public channel.

## Disclosure and Remediation

WhittakerTech has not formally adopted response-time targets, remediation
deadlines or a disclosure schedule for this project, and none are promised
here. Fixes for supported versions are released as new versions and recorded in
`CHANGELOG.md`.
