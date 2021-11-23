# Release Hosting
The legacy process of hosting .zip files at the root of the git repository is easy/simple, but has issues:
 - Every zip increases git repo size, making git clones take longer and longer over time.
 - No easy way to see what's different in each port.
 - Max file size of 100MB, meaning some ports like UQM and SuperTux have to be hosted somewhere else, leading to more complexity.

The updated `./build` process will create zips under `./release` - these zips *can* be used to update the legacy zips.  However, the intent is to create a different process which `portmaster` can then use for downloads.

In short - the new release hosting process will simply use github releases to host all zips. The 'latest' release will be used by portmaster so that the download code is almost identical.  To avoid rebuilding all ports for every release, remote build caching (`./build --remote-build-cache`) makes it so that zips that have not changed and just be re-downloaded from a previous release and re-published.

Advantages:
- No 100MB file size limit
- Very similar download code for PortMaster
- Zips can be removed from root of repository (at least once they are not used by any `LEGACY_PORTMASTER=true` builds)

Disadvantages:
- Requires automation as each release has all ports - but we can use github actions to automate for free.

## Hosting Structure
There is a github action which can be triggered to create a release.  This action will build all ports (using caching of prior releases to speed build) and publish a release with the format: `YYYY-MM-DD_HHMM` ex: `2021-11-18_2337`.  

This release will have .zips for all ports as well as `.git.info` files which contains the caching metadata used to determine if a build has changed.

Though there are some minor differences with GitHub Releases (spaces are turned into '.'), portmaster can be updated to point to the following url and it more or less works: `https://github.com/<org>/PortMaster/releases/latest/download/`