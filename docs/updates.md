# Update versions and channels

## User-visible behavior

Settings → About → **Receive prerelease updates** is an app-wide, saved opt-in.
It defaults to **off**, including for existing installations and installations
whose own version is an Alpha, Beta, or RC.

- **Off:** offer only stable releases.
- **On:** include stable and prerelease releases and choose the highest eligible
  SemVer version. This does not force a downgrade to a prerelease.
- Draft releases are never offered. A release counts as a prerelease if its
  version has a prerelease suffix **or** its `prerelease` flag is true.
- Changing the setting clears the cached update badge. A request that finishes
  after its channel changes cannot restore an old badge or show an old dialog.
- The setting does not start a network request, download, or installation.
  Manual checks and checks using the startup coordinator share the same policy.
- Ignoring an RC does not ignore a later RC or the final release of that version.

## Version precedence

Use SemVer prerelease identifiers, for example:

`2.3.1-alpha.1 < 2.3.1-alpha.2 < 2.3.1-beta.1 < 2.3.1-rc.1 < 2.3.1`

Numeric identifiers compare numerically, so `rc.10 > rc.2`. Numeric identifiers
sort before nonnumeric identifiers, and text identifiers compare by ASCII order
(case-sensitive). Build metadata after `+` does **not** affect update precedence.
Historical one- and two-component versions remain readable as zero-padded core
versions, and a leading `v` or `V` release-tag prefix is accepted. Malformed tags
(such as `2.3.1-rc.`) are not update candidates.

For a Flutter release, a version can be written as `2.3.1-rc.1+15` in
`pubspec.yaml`, with a matching GitHub tag such as `v2.3.1-rc.1`. Continue
incrementing the platform build number for distributed packages: operating-system
installation rules are separate from the app SemVer check. Increasing only the
build metadata does not produce a new in-app update notification.

The app reads Flutter’s `appBuildName` before falling back to the native package
version. This retains prerelease identifiers on iOS/macOS, whose native version
fields normalize or omit them. Native packaging and store-version requirements
still apply independently.

## Rolling out this change

Older installed clients still use their original numeric-only comparison and
GitHub latest-release endpoint. Publishing this code does not change those
clients: distribute it in a stable release with a higher numeric core version,
or have testers install a prerelease package manually. An old client on an RC
may not detect a final release with the same numeric core.

## GitHub releases

The default source is the repository’s paginated GitHub Releases API, not
`/releases/latest`, because the latter does not return prereleases. Every page is
considered before choosing the highest eligible SemVer version; API creation
order is not treated as version precedence. Invalid/non-versioned historical
entries are skipped. Request or pagination failures are reported as failures,
not as “already up to date.” The update link points to the selected release.

## Custom update feed

`--dart-define=SKED_UPDATE_VERSION_URL=https://example.com/sked.json` continues
to support the existing single-release object. To offer both channels from one
endpoint, return a `releases` array:

```json
{
  "releases": [
    {
      "version": "2.3.1",
      "releaseUrl": "https://example.com/releases/2.3.1",
      "updateContent": "Stable release notes"
    },
    {
      "version": "2.4.0-rc.1",
      "prerelease": true,
      "releaseUrl": "https://example.com/releases/2.4.0-rc.1",
      "updateContent": "Release candidate notes"
    }
  ]
}
```

The existing `tag_name`, URL, and notes aliases still work. Optional
`prerelease` and `draft` flags must be booleans; both sources apply the same
channel rules. A legacy single-release feed containing only a prerelease does
not offer an update to stable-channel users. It must publish a release array if
those users should also receive an available stable release.
