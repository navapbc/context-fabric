# Design

## A second in-place amendment of contract 1

The first amendment was made in place because contract 1 had never been
released: immutability protects readers, and there were none. That is still
true. No release has been cut and no document outside this repository declares
contract 1. So this change amends `schemas/shared/1` and `schemas/view/1` in
place and moves their frozen digests. The comment beside the frozen digests is
rewritten to record both amendments and to keep the rule it stated: the first
release ends in-place change for good.

## The denylist boundary is negated

The anchored entries used to accept a path only after the start of a string, a
line break, a space, a tab, `(`, `,` or `=`. Listing boundaries leaves out the
next spelling: a backtick, a quote, `->`, `=>`, `@`. The boundary is now any
character that cannot continue a URL host, a port, or a relative path segment:
anything but a letter, a digit, and `.` `_` `~` `*` `%` `+` `/` `-`. That keeps
a URL path (`https://host/home/x`), a port (`host:8080/var/x`) and a relative
path (`src/tmp/`) passing, and it is a strict superset of the old boundary.

`*` is deliberately not a boundary. A Bounded Context's `path_scope` is checked
by the same shared-tier scan as every other string, and a glob such as
`**/tmp/` is a legitimate scope. A colon is a boundary, so an scp-style
`host:/var/www` is rejected: it names one machine's filesystem, which is what
the rule exists to keep out of shared documents.

## The host-tool explanation is framework text

A view carries values and no authored text. The explanation is neither: it is a
fixed sentence the generator emits for one enum value, the same for every
document. It goes in `view.yaml` because the generated instruction tells an
agent that is the file to read, and in `view.md` because that is the rendering a
person reads. The view contract admits the field on a `host-tool` interface's
`auth` object only.
