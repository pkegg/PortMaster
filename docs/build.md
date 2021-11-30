# tldr; - build a port
- install [docker](https://docs.docker.com/get-docker/) on linux/mac/wsl2.
- check install with: `./init-docker`
- `./build <port name>`
- Find the output zip under `./release/<PKG_NAME>.zip`

# Build Scripts Overview
The build uses docker buildx to provide the dependencies and the docker+qemu emulation needed to run builds for arm/arm64 platforms.  Builds are smart enough to only rebuild if changed.  Having a build system means port builds are repeatable, easier to add and and can include common files/dependencies across all ports.

With docker, builds can be run on linux (Ubuntu 20.04 tested), mac (x86 and m1) and windows (via wsl2 with ubuntu 20.04).  Default build environment is Ubuntu 20.04 x64 - other platforms are known to work, but are only supported on a 'best effort' basis.

NOTE: Running in `christianhaitian`'s Ubuntu VM with debian arm chroot also works.  As the chroot does not have docker, the chroot must be the appropriate platform (arm64, arm32, etc) and dependencies must be manually installed with: `ports/install-deps`, `ports/<port>/install-deps` or manually by the user.

Most scripts are located in `./ports` but frequently used scripts (`build`, `clean`, etc) are added at the top level for convenience.
- `./build <port>` - The main script to build a specific port. By default, it uses auto-generated Dockerfiles to provide build environment via docker.  
  - Uses: `ports/install-deps` to provide environment.  Specific ports can add their own packages via `ports/<port>/install-deps`.
  - Options:
    - `--no-docker`- can be used to run a build w/o docker (dependencies must exist on host).  Known to work in christianhaitian's chroot and Ubuntu 20.04
      - `--install-deps` - Automatically install dependencies if docker is not installed.  Useful in a chroot. 
    - `--no-build-cache` - Run a rebuild rather depend on the build cache.
    - `--docker-remote` - Helps to simulate build server and will not use local docker images
    - see `--help` for full list.  Most other options are only used by github actions during build and/or `./build-all`

- `build-all` - calls `build` for all ports. Accepts all `./build` parameters and will pass them through.
- `bump-versions` - updates `PKG_VERSION` in package.info files to the latest git version.  Respects `PKG_BRANCH` or will use default branch.
- `clean` - cleans out temporary files copied by build and building.  `./clean --ccache` will remove ccache too (if used by a port).
- `clean-all` - calls `clean` for all ports.
- `init-docker` - Checks docker is installed.  Installs docker buildx and qemu emulation for docker if not already installed.
- `ports/build-base-image` - builds the top level `Dockerfile` (`install-deps`).  Not required unless changing `ports/install-deps`
- `run` - This is what is run on-device to start the port.  

Some directories/files are created as part of the build but ignored by git:
- `source` - where the source of the PKG_URL is put.  Build is smart enough to `fetch` latest git if source already exists.
- `pkg` - The directory which will be included as part of the zip.  It is deleted before each build that is run.


# Port Requirements
Each port has a standard layout in the `ports` directory.  The following shows conventions and requirements for port builds and packaging.  The build format is inspired by the LibreElec `package.mk` format, but is kept lighter weight and instead uses the file name `package.info` to indicate it's not compatible.

All packages implicitly have a dependency on `global` unless `PKG_GLOBAL=false` is set. This allows packages to utilize `global-functions` for reuse across ports.

## Port Directory Layout
The following files can be used to build a port.
- `<port folder>` - must be lower case and valid in a docker tag (lower case)
  - `package.info` (Required) - provides information about the package and it's source.
    - NOTE: this is similar to the EmuELEC package.mk format.  It is called package.info to show its not totally compatible.
    - `PKG_NAME` (Required) - The name of the package.  Can include spaces, etc.  Will be used for name of zip and main script.
    - `PKG_DIRECTORY_OVERRIDE` - By default, there is a directory inside the zip which matches the port folder name.  This allows customizing the directory in the zip.
    - `PKG_ZIP_NAME_OVERRIDE` - By default, the zip is named according to `PKG_NAME`.  This allows overriding the name of the output zip file.
    - `PKG_URL` - The source code url.  Will be cloned into `source`. Smart enough to do a `git pull` if already exists.
    - `PKG_VERSION` (Required - if PKG_URL) - the version of source code - typically git hash or tag.  
      - NOTE: though a branch name (`main`) is technically allowed for now, it is not 'supported' as the package will not be rebuilt unless something changes in the ports directory.  See the build caching section.
    - `PKG_DEPENDS` - A comma separated list of dependent packages which will be built first and included in it's `pkg`.  Dependent packages will be built and their `pkg` contents into this ports `pkg` folder.  Transitive dependendencies (package A depends on B which depends on C are not supported) to keep things simple.
      - NOTE: `PKG_DEPENDS` artifacts cannot be utilized by the `build` step, but only the `package` step.  This enables depedency updates to only require repackaging and not a full rebuild.
    - `PKG_LIBRARY` - Means this package can be used in another `PKG_DEPENDS`.  Used to 'pre-build' all libraries on build server.
    - `GET_HANDLER_SUPPORT` - currently only `git` and `archive` are supported. Can be left off and defaults to `git` if PKG_URL is set.
    - `PKG_GLOBAL` - If set to `false`, global depedencies will not be copied in.
    - `LEGACY_PORTMASTER` - Setting this enabled building from *previous* portmaster zips located in the root of the repository.  This makes it easy for builds to stay up to date with zips that have not been updated to the new build proces.  Only `PKG_NAME` is required if `LEGACY_PORTMASTER` is set.
    - `LEGACY_URL_OVERRIDE` - Setting this along with `LEGACY_PORTMASTER=true` allows pointing to a location to download zips too big to be checked into github (UQM, SuperTux, etc).  Ex: `LEGACY_URL_OVERRIDE="http://139.196.213.206/arkos/ports/UQM.zip`
    - `BUILD_PLATFORM`- Allows setting the platform used via Docker to build.  Defaults to: `linux/arm64/v8`.  
      - Valid choices are: `linux/arm64/v8`, `linux/arm/v7` (32 bit arm), `linux/amd64` (64 bit x86 - for cross compile) and `any` (builds w/o binaries)
    - `TEST_PLATFORM`- Allows setting the platform used via Docker to run tests.  Defaults to `BUILD_PLATFORM`.
    - `PKG_NO_MAIN_SCRIPT` - By default, ports zip has a main script (`<PKG_NAME>.sh`) at the root of the zip.  If this is set to true, exclude it (ex: `portmaster`)

  - `build` - script to run build.
    - Will be run from `source` directory if one was created or the port directory if one does not exist.
    - The script can output build artifacts to the `pkg` directory.  For longer builds or complex packaging logic, it is suggested to use a `package` script.  This allows faster rebuilds on packaging changes even in the cloud.
    - NOTE: Will be run with bash.
  - `package` - script to package build.
    - Will be run from the port directory and should populate the `pkg` directory.  Should only use `bash` as it is currently not run in a container.
    - Not strictly required if copying files into `pkg` is done in the `build` script.  But convenient if `build` takes a long time.
  - `test` - will run tests inside a docker image
  - `install-deps` - provides any addition dependencies for build beyond main Dockerfile.
  
# Build Caching Overview
**tl;dr;** Caching is important, so we made a caching layer to speed up builds.  Disable it on build with `./build --no-build-cache`.

---

Caching builds is quite important due to a variety of factors:
  - Takes a long time to build certain ports (CPU intensive, etc)
  - The sheer *number* of ports in PortMaster.
    - If we build them all squentially, it could take many hours (or days) to build even if they build pretty fast.  There won't ever be 'less' ports.
  - The low CPU specs of Github Actions 'free' builders
    - Ideally - we use GitHub actions to build for free - but the free builders are not particularly powerful

To address this, we've create a build caching system that can be used to determine if a given port needs to be rebuilt (or it's dependencies rebuilt and it repackaged).  Initially docker was considered, but the sheer scale of number of docker images being created caused issues in github's container registry and errored very unreliably.

**Build Caching 101: Something must change in a port folder for it to be rebuilt**
The main idea is that: in order for a port to be rebuilt, something that ports folder *must* change.  This makes it easy to take a `hash` of the files in the directory to determine if anything has changed.

This is a big reason why `PKG_VERSION` cannot/should not be set to `main` an instead is set to the git hash.

At it's simplest, the build caching system just uses git to look at the last change hash on a port folder (and dependent folders) and records that in a .git.info file.  Ex:
```
portmaster=52b0424
global=3f9a625
oga_controls_portmaster=4d151fc
dialog=52b0424
```

Then, it is easy to determine if a port needs to be rebuilt.  In the above example, if the `portmaster` lines change - `portmaster` needs to be rebuild.  If the dependencies change, those dependencies need to be rebuilt and portmaster needs to be repackaged.

This works great for a build server, but what about local changes?  In the case of local changes, any files known to git are recorded and then hashed.  This makes it so even local changes use this smart caching behavior. 

Ex:
```
portmaster=52b0424
portmaster_dirty=control.txt,package.info,
portmaster_dirty_hash=9db57015f8a83455700dc20621ac5becb76b03f3
global=3f9a625
oga_controls_portmaster=4d151fc
dialog=52b0424
```

If there are issues - or something outside of a port folder needs to retrigger a build, `--no-build-cache` can be used.

## Remote Build Caching
By default, `./build` does not look at github releases for build cache due to the high number of API request to do so and only looks at local files in `./releases`.  Remote build caching can be enabled by running `./build --remote-build-cache` and is used when running with GitHub Actions.  In order to use, `export GITHUB_TOKEN=<token>` must be run in your terminal to provide a valid token and increase GitHub's API rate limit from 60 request an hour.  
See: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token

Remote build caching will use GitHub APIs to evaluate the previous releases `.git.info` files and see if it matches your local files.  If it's a match, the port's `.zip` will be downloaded and used instead of fully rebuilding.  `./build` is smart enough to detect cases where dependencies have changed so only repackaging is needed.  This allows quick rebuilds of things like `global` or `oga_controls` without rebuilding a ton of packages
