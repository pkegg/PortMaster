# Backwards Compatibility
In general - the new build system approach aims to keep backwards compatibility or provide easy ways to transition to the new approach with a minimum of disruption when the project is ready.  

**tl;dr**: Everything should be able to merge cleanly with no disruption.  When `/PortMaster.zip` changes will determine rollout to anything new.

- **Build**
  - `/ports` (or associated scripts) do not overlap with anything existing.  Can be included with no issues
  - `/ports/portmaster` (the './build' version of PortMaster.zip) is duplication of `/PortMaster` with the new build approach.  However, it is not required to be used.
  - If any ports with `./build` implemented are broken, we could switch them back to `LEGACY_PORTMASTER=true` (and just use old zips) until they are fixed.
  - Scripts could be used to manually build and update root `.zips` in "legacy" manner until we are ready to update PortMaster.zip.


- **GitHub Automation**
  - GitHub releases are only created manually via GitHub Actions.  So no releases will happen until we are ready.  So should be no impact/confusion there.
  - GitHub actions will start building commits to `main` and `PR`'s. This might be a bit confusing as `.zips` won't initially be used, but will still provide a way to test if things are working without disrupting anything existing (can download built ports from the Actions run in GitHub)

- **Release Hosting**
  - Once a release is created, it still won't be disruptive to old users until the `.zip` files in the root directory are removed.
  - Likely we will always want to keep an updated `PortMaster.zip` in the root directory forever so old clients can update to a 'new' PortMaster which will read GitHub Releases.

- **PortMaster**
   - `/ports/portmaster` includes a refactored version of PortMaster using the new build functionality which utilizes `global-functions` and downloads from releases.
    - We **could** switch to it at some point (update `/PortMaster.zip`) and set LEGACY=true as default.  This would basically rollout the new portmaster, but still download everything as before.  If that works, update PortMaster.zip again to LEGACY=false.