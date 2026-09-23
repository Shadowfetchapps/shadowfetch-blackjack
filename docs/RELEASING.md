# Releasing

1. Bump `config/version` in `project.godot`, `X-AppVersion` in `tools/install-user.sh` and the default version in
   `tools/package_release.sh`; add a `CHANGELOG.md` entry.
2. Run `./tools/run_tests.sh` (all green) and, for engine changes, the edge check.
3. Refresh screenshots if the look changed: `SF_BJ_QA=shots SF_BJ_QA_OUTPUT=docs/screenshots godot --path .`
4. `./tools/package_release.sh` → `export/shadowfetch-blackjack-<version>-linux-x86_64.tar.gz` and `.sha256`.
   The tarball contains the self-contained binary, icons, install/uninstall scripts, README, CHANGELOG and LICENSE.
5. Tag `v<version>`, push, and publish a GitHub release with the tarball and checksum:

   ```bash
   gh release create v3.0.0 export/shadowfetch-blackjack-3.0.0-linux-x86_64.tar.gz{,.sha256} \
     --title "Shadowfetch Blackjack 3.0.0" --notes-file <notes>
   ```

6. Update the local install with `./tools/install-user.sh`.

Export templates for Godot 4.7.2 must be installed (`~/.local/share/godot/export_templates/4.7.2.stable`).
