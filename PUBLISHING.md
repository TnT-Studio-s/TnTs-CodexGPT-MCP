# Private Source, Public Releases

This repo is the private source tree for Codex Buddy.

The public-facing repo should only hold release assets, not source. A good default split is:

* private source repo: `owner/codex-buddy`
* public releases repo: `owner/codex-buddy-releases`

Recommended flow:

1. Keep all source code, helper scripts, and build logic in the private repo.
2. Run `build-release.ps1` to compile `CodexBuddy.exe` and stage the release zip locally.
3. Publish only the finished artifact to the public releases repo.
4. Never push the raw source tree into the public repo.

Important security note:

If the release asset contains raw PowerShell source, users can read it. That setup is fine for separation, but it does not hide the code. If you want real source protection, the release should be a compiled binary or another non-source artifact.

Suggested GitHub setup:

```powershell
gh repo create owner/codex-buddy --private --source . --remote origin
gh repo create owner/codex-buddy-releases --public --clone
```

Suggested release flow:

```powershell
git tag v1.0.0
gh release create v1.0.0 --repo owner/codex-buddy-releases --title v1.0.0 --notes "Release v1.0.0"
gh release upload v1.0.0 --repo owner/codex-buddy-releases path\to\artifact.zip --clobber
```

Keep the public repo small and boring:

* release notes
* download assets
* checksums, if you want them

Leave source, internal scripts, and private docs in the private repo.
