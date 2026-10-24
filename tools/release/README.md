# Desktop release publishing

`.github/workflows/release.yml` requires a strict `vX.Y.Z` tag on `origin/main`,
the complete reusable playtest workflow, both production builds, and the `release`
environment approval before publishing. Exact artifact names and build-job digest
outputs are required; build provenance is attested from `dist/SHA256SUMS` before
the publisher runs. Do not bypass these gates for a repair.

`release.py verify-publish` validates the exact twelve downloaded build files
(four packages, their JSON records and individual checksums), then generates
`SHA256SUMS`. Exactly **nine assets** are published: the four packages, their
four JSON records and `SHA256SUMS`. The individual checksum files stay local.
`publish_release.py` repeats the same build-output digest checks immediately
before using GitHub. An existing `SHA256SUMS` is accepted only if its contents
match those build outputs exactly; all other extra/missing files remain errors.
Keep release notes and logs outside `dist/`.

## Rerun behavior

The helper uses bounded `gh` subprocesses without a shell (300 seconds per
command), explicit repository selection, and REST response status codes rather
than parsing CLI error text. It verifies repository access and the existing
remote tag first. Only a release lookup's HTTP 404 means that release may be
absent; authentication, transport, malformed-response and other API failures
stop the run. Draft discovery also checks the authenticated release listing
because REST's tag lookup does not necessarily expose drafts. Discovery stops
with an error after ten pages of 100 entries, never with an assumed absence.

| Remote state | Action |
| --- | --- |
| No release | Create a draft with `--verify-tag`, `--latest=false` and `--prerelease=false`. Re-read its identity and draft state. |
| Empty published release | Return it to draft, explicitly disable latest, and re-read that draft state before uploading anything. |
| Partial matching draft | Keep matching assets; upload only missing names. |
| Partial matching published release | Return it to draft and verify that transition before resuming missing uploads. |
| Complete matching draft | Verify all assets again, then publish and make latest. |
| Complete matching published release | Do not hide or re-upload it. If its canonical title/notes already match, perform only reads. |
| Conflicting, unexpected, duplicate or unverifiable asset | Fail without overwriting/deleting assets. An absent digest or `starter` upload state is not a match. |

Every remote asset must have the exact expected name, uploaded state, byte size,
and GitHub-reported `sha256:` digest, including the JSON records and manifest.
A 100-entry asset page is sufficient: only nine names are permitted, so a full
page is necessarily invalid. Uploads never use `--clobber`. After uploading,
re-read all assets and release identity/metadata before promotion. After
promotion, re-read the exact release, its assets, and `/releases/latest`; a
successful PATCH or upload alone never means completion. New releases retain
GitHub's generated changelog after the canonical installer instructions; that
suffix is read back and preserved across retries, not regenerated. Repairing an
older release without those instructions installs the canonical template/title.

A failed create/upload/publish command stops immediately, even if GitHub might
have accepted the request before the connection failed. The next invocation
reconciles actual remote state. Failed uploads normally leave a hidden draft;
a successful publication followed by a failed readback may leave a complete
published release, but the invocation still fails until a rerun verifies it.
Already-complete canonical releases are not silently re-promoted over a newer
latest release: a mismatched `/releases/latest` is an error requiring review.

Rerun the approved publishing job with the **same original build artifacts and
build-job digest outputs**. Rebuilding can produce different bytes; a conflict
is intentional and must be reviewed, not worked around with clobber or deletion.
A workflow rerun at an old tag uses that tag's workflow/tooling, not newer fixes
on `main`; an old-tag repair must separately use reviewed tooling and preserve
the original test/build/approval/attestation evidence. The helper itself is not
a replacement for those gates.

The workflow serializes runs per tag. Do not manually edit releases, their tags,
or upload assets during a publishing run. GitHub offers no atomic transaction
across asset upload, release metadata and latest selection; concurrent external
edits can still cause a readback failure and require inspection. Immutable
releases and old assets without GitHub digests cannot be silently repaired.

## Offline verification

No test calls GitHub. `tests/test_publish_release.py` supplies HTTP-shaped
REST responses and stateful `gh` fixtures through the real subprocess seam,
including accepted-but-response-lost uploads, draft discovery, reruns,
conflicts, command failures and unsuccessful final readbacks.

```sh
# Set TMPDIR to a writable local scratch directory if your host requires it.
tools/art/.venv/bin/python -m unittest discover -s tools/release/tests -v
actionlint .github/workflows/release.yml
git diff --check
```

The complete Python suite includes real native package/install tests where the
host tools are available. Give it a sufficient bounded timeout (600 seconds),
not a short smoke-test timeout.
