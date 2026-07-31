# macOS Developer ID release runbook

Burrow’s GitHub/Homebrew release path distributes a ZIP outside the Mac App
Store, so it needs a **Developer ID Application** certificate and Apple
notarization. It does not need a Developer ID Installer certificate because it
does not ship a signed installer package.

The tag workflow is fail closed. It checks the six signing/notarization
credential values and the external-tap token before building, signs every
Mach-O file with hardened runtime and a secure timestamp, submits the ZIP to
Apple, requires an `Accepted` result, staples the ticket, and runs both strict
code-signature verification and Gatekeeper assessment. Only then can it
publish a GitHub release or update Homebrew.

## 1. Create the certificate signing request

Follow Apple’s
[Keychain Access CSR workflow](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request):

1. Open **Keychain Access → Certificate Assistant → Request a Certificate From
   a Certificate Authority**.
2. Enter the email address attached to the Account Holder’s Apple Account.
3. Use a recognizable common name such as `Burrow Developer ID 2026`.
4. Leave the CA email address empty, choose **Saved to disk**, and save the
   `.certSigningRequest`.

The CSR is safe to upload to Apple. The private key created with it stays in the
login keychain and must never be committed, uploaded as an Actions artifact, or
sent in chat.

## 2. Create and export the Developer ID Application identity

In [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list):

1. Choose **Certificates → + → Software → Developer ID → Developer ID
   Application**.
2. Upload the CSR, download the resulting `.cer`, and double-click it to install
   it in the same keychain that holds the CSR’s private key.
3. In Keychain Access, open **My Certificates**. The new `Developer ID
   Application: … (TEAMID)` certificate must expand to show its private key.
4. Export that certificate and private key together as a password-protected
   `.p12`. Generate a unique password and store it in the password manager.

Confirm the exact identity string before configuring CI:

```bash
security find-identity -v -p codesigning
```

Apple limits Developer ID certificate creation and revocation has a large
blast radius, so keep one protected release identity instead of generating a
new certificate per build.

## 3. Create the notarization API key

The workflow uses an App Store Connect **Team API key**. Apple explicitly
excludes Individual API keys from `notarytool`.

1. Open **App Store Connect → Users and Access → Integrations**. If API access
   is not enabled, the Account Holder must request it and wait for Apple’s
   approval.
2. Under **Team Keys**, generate `Burrow Notarization` with the **Developer**
   role. This is the least-privilege practical role for the release key.
3. Download `AuthKey_<KEY_ID>.p8` immediately; Apple allows the private key to
   be downloaded only once. Record the Key ID and Issuer ID beside it in the
   password manager.

Validate the key locally before creating a tag:

```bash
xcrun notarytool history \
  --key /absolute/path/to/AuthKey_KEYID.p8 \
  --key-id KEY_ID \
  --issuer ISSUER_ID
```

If Apple rejects that role for this team, revoke the key and recreate it with
the next required role; App Store Connect does not allow an existing key’s
access level to be edited.

## 4. Add the GitHub Actions secrets

Run these from a machine where `gh auth status` confirms access to
`caezium/Burrow`. The two pipelines stream base64 directly into GitHub and do
not print private-key material:

```bash
/usr/bin/base64 < /absolute/path/to/Burrow-Developer-ID.p12 \
  | gh secret set MACOS_CERT_P12 --repo caezium/Burrow

/usr/bin/base64 < /absolute/path/to/AuthKey_KEYID.p8 \
  | gh secret set AC_API_KEY_P8 --repo caezium/Burrow
```

Set the remaining values interactively so they do not enter shell history:

```bash
gh secret set MACOS_CERT_PASSWORD --repo caezium/Burrow
gh secret set MACOS_SIGN_IDENTITY --repo caezium/Burrow
gh secret set AC_API_KEY_ID --repo caezium/Burrow
gh secret set AC_API_ISSUER_ID --repo caezium/Burrow
```

`TAP_PAT` is also required. It should remain the existing fine-grained token
scoped only to `caezium/homebrew-tap`, with repository **Contents: Read and
write** permission.

The required names are:

- `MACOS_CERT_P12`
- `MACOS_CERT_PASSWORD`
- `MACOS_SIGN_IDENTITY`
- `AC_API_KEY_ID`
- `AC_API_ISSUER_ID`
- `AC_API_KEY_P8`
- `TAP_PAT`

`MACOS_SIGN_IDENTITY` is the full output name, including the team ID:
`Developer ID Application: Name (TEAMID)`.

Confirm only the names and timestamps, never their values:

```bash
gh secret list --app actions --repo caezium/Burrow \
  | grep -E '^(MACOS_|AC_API_|TAP_PAT)'
```

After the secrets are stored, move both private-key files out of Downloads and
into the password manager’s encrypted file storage. Keep a tested backup of the
`.p12`; losing its private key prevents signing updates with that identity.

## 5. Cut and verify the first signed release

Merge the signing change, choose the next app version and build number, and
update the release notes before tagging. Do not reuse or move an existing
public tag.

The workflow order is:

1. Require all signing and notarization secrets.
2. Build and confirm the bundled conductor, engine, and fclones sidecar.
3. Sign every executable and the outer app with Developer ID.
4. Require Apple’s notarization result to be `Accepted`.
5. Staple and validate the ticket, then require Gatekeeper acceptance.
6. Package and publish the exact verified app.
7. Update `caezium/homebrew-tap`, removing the legacy quarantine bypass and
   unsigned warning only after the verified artifact exists.

Download the release asset and verify the distributed copy:

```bash
ditto -x -k Burrow-VERSION.zip verified-release
codesign --verify --deep --strict --verbose=2 verified-release/Burrow.app
codesign -d --verbose=4 verified-release/Burrow.app
xcrun stapler validate verified-release/Burrow.app
spctl --assess --type execute --verbose=4 verified-release/Burrow.app
```

The final `spctl` result must identify the source as `Notarized Developer ID`.
Check that Homebrew’s live `Casks/burrow.rb` no longer contains `postflight`,
`xattr -cr`, or an unsigned-build caveat.

Once those checks pass, move “Signed & notarized macOS builds” from **Building**
to **Recently shipped** in `docs/roadmap.json`, add the shipped version, and run
`python3 scripts/site-release.py`. Do not make that documentation transition
before the distributed artifact and live cask have both been verified.

## Telemetry and signing

Signing and notarization do not require new in-app telemetry. CI records only
release-operational evidence in the private Actions log: the number of signed
Mach-O files, certificate authority and team ID, Apple submission ID/status,
stapler result, and Gatekeeper verdict. No new PostHog or Sentry event is added.

Burrow’s existing opt-out telemetry behavior remains unchanged. The checked-in
privacy manifest is the store-facing declaration, while
[`TELEMETRY.md`](../TELEMETRY.md) remains the human-readable source of truth.

## Mac App Store later

A Mac App Store build is possible only as a materially reduced product. Apple
requires App Sandbox, and embedded command-line tools inherit that sandbox.
Burrow’s core product deliberately scans broad filesystem locations, inspects
processes and ports, launches bundled cleanup tools, invokes Homebrew, and
offers administrator-assisted operations. Those behaviors do not fit the
current sandboxed bundle.

The credible store version would be a separate SKU with a separate bundle ID:
user-selected folders via security-scoped bookmarks, read-only status features,
and no broad cleanup, privileged shell, Homebrew management, or general MCP
system-tool surface. That is worth building only if App Store discovery or
managed-store deployment creates enough demand for the reduced feature set.
Developer ID plus notarized GitHub/Homebrew distribution should be proven first.
