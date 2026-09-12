# Release notes

The generator (`release-notes.sh`, from mavericks-shipyard) writes the notes file for every
release: the title, a "What changed" section, a "Build ingredients" section when a pin moved,
and the footer. That file becomes both the Sparkle appcast `<description>` and the GitHub
Release body -- the same bytes, read twice.

A file here, named `<tag>.md` (e.g. `v0.5.4.md`), is OPTIONAL hand-written prose for that one
release. When present, it is inserted verbatim right after the generated title. It must NOT
start with its own `## ` heading -- the generator already emits the title; a second one would
double it.

Most releases have no file here at all, and that's fine: the generator's own sections are the
whole note.
