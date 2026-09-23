# Releasing

1. Bump `config/version` in `project.godot` — it is the single source of the version: `package_release.sh` names the
   tarball from it and writes it to `VERSION` in the package, which `install-user.sh` puts in the desktop entry.
2. Add a `CHANGELOG.md` entry and update version mentions in `README.md` (badge text updates itself).
3. Run `./tools/run_tests.sh` (all green). For engine or strategy changes also run the edge check
   (`godot --headless --path . --script res://tests/edge_check.gd`).
4. Refresh screenshots if the look changed. Use a scratch save folder and fullscreen so captures are full resolution:

   ```bash
   mkdir -p /tmp/qa/config
   echo '{"version":3,"fullscreen":true,"quality":"ultra","seen_tutorial":true}' > /tmp/qa/config/settings.json
   SHADOWFETCH_BJ_HOME=/tmp/qa SF_BJ_QA=shots SF_BJ_QA_OUTPUT=docs/screenshots godot --path .
   ```

5. `./tools/package_release.sh` → `export/shadowfetch-blackjack-<version>-linux-x86_64.tar.gz` and `.sha256`
   (checksum file uses a relative name, so `sha256sum -c` works anywhere). The tarball contains the
   self-contained binary, prebuilt icons, `VERSION`, the install/uninstall scripts, README, CHANGELOG and LICENSE.
6. Smoke-test the packaged binary:
   `SHADOWFETCH_BJ_HOME=/tmp/rel SF_BJ_QA=smoke export/linux/shadowfetch-blackjack.x86_64 --headless`.
7. Commit, tag `v<version>`, push, and publish the release with the tarball and checksum:

   ```bash
   gh release create v<version> export/shadowfetch-blackjack-<version>-linux-x86_64.tar.gz{,.sha256} \
     --title "Shadowfetch Blackjack <version>" --notes-file <notes> --latest
   ```

8. Update the local install with `./tools/install-user.sh`.

Export templates for Godot 4.7.2 must be installed (`~/.local/share/godot/export_templates/4.7.2.stable`).
