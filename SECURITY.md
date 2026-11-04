# Security Policy

## Report a Vulnerability

Report a vulnerability in NCode.ReparsePoints privately. Never put it in a public issue, pull request or discussion: that tells attackers about it before a fix exists.

On the repository's **Security** tab, choose **Report a vulnerability**. The report reaches the maintainers only, and the fix is discussed in a private security advisory until it is released. If the tab has no such button, open an issue that asks for a private contact, and leave out every detail of the vulnerability.

[//]: # "Maintainers: the button appears once private vulnerability reporting is turned on in the repository's security settings."

Include:

- what is affected: the package and its version, and the file, endpoint or feature;
- how to reproduce it, as steps or a proof of concept;
- what it lets an attacker do;
- any fix or mitigation you know of, and how you'd like to be credited.

## What to Expect

- An acknowledgement of the report, then whether it is confirmed.
- A fix developed in private and released as soon as it is ready, with an entry under `### Security` in the changelog.
- Disclosure coordinated with you: the security advisory is published once the fix is released. Keep the details private until then.
- Credit for the report in the advisory, unless you'd rather not be named.

## Supported Versions

Fixes ship as a patch of the latest minor version of the current major version. Before 1.0.0, only the latest release gets fixes.

| Version | Fixes |
| --- | --- |
| The latest minor of the current major, such as 2.3.x while 2.3 is the newest minor | Yes |
| Every older version | No |

## Verify a Package

The packages are built in CI from a tagged commit of this repository, deterministically and with Source Link. They reach nuget.org only through `.github/workflows/publish.yml`, which publishes them from a published GitHub release through nuget.org trusted publishing: no long-lived API key exists, and each package's version is its release's tag.

- Each package's PDB maps every source file to its commit in this repository, and its symbol package (`.snupkg`) is on the nuget.org symbol server. With Source Link and the nuget.org symbol server turned on in your debugger, you step into the exact source a package was built from. NuGet Package Explorer shows whether a package's Source Link and deterministic build are valid.
- nuget.org signs every package it accepts: `dotnet nuget verify --all <package>.nupkg` checks that signature.

## Scope

In scope: the code, build and CI configuration in this repository and the packages built from it, including a vulnerability that comes from how NCode.ReparsePoints uses a dependency.

Out of scope: a vulnerability in a dependency itself. Report it to that project. Once it publishes a fix, an issue or pull request here that moves to the fixed version is welcome, though Dependabot usually proposes it first.
