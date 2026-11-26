# Contributing to Saman

## Report an issue

Search [existing issues](https://github.com/israelor6/saman/issues) first. For a selection bug, include the app where it happens, your macOS and Saman versions, and a reproduction using a sample sentence. Use the private route in [SECURITY.md](SECURITY.md) for a vulnerability.

## Send a change

Fork the repo, branch from `main`, and open a pull request. Explain the behavior change and what you verified. For visual changes, share screenshots using sample data. Keep equivalent copy in all interface languages under `Resources/*.lproj`, and check keyboard interaction and reading direction in English, Hebrew, and Spanish.

Build on an Apple silicon Mac with the macOS 27 SDK.

```sh
./scripts/build.sh
./build/Saman.app/Contents/MacOS/Saman --check --skip-models
```

With English and Hebrew translation models installed, run the full `--check` as well. Verify Accessibility and Open at Login manually when changing those flows.

The static website lives in `docs/`. Preview it with `python3 -m http.server --directory docs 8000` and open `http://localhost:8000`. GitHub Pages publishes this folder from `main`.

## Release checklist

1. Update the marketing and build versions in `Resources/Info.plist` and add a changelog entry.
2. Build and run the full on-device check. For a Developer ID release, sign with hardened runtime and complete Apple notarization before packaging.
3. Run `./scripts/package.sh`. It verifies the app, creates the ZIP and checksum, and verifies the extracted bundle.
4. Create a draft GitHub release for the tested commit, attach the ZIP and checksum, and describe the signing status and macOS requirement. Publish after verifying the draft. Keep the asset name `Saman-macOS.zip` so the download URL stays stable.
