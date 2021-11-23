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
    - `PKG_VERSION` (Required - if PKG_URL) - the version of source code - must be git hash or tag as, due to caching, the ackage will not be rebuilt unless a file changes in the ports directory (ex: `main` would never be updated).
    - `PKG_DEPENDS` - A comma separated list of dependent packages which will be built first.  Dependent packages will be built and their `pkg` contents into this ports `pkg` folder.
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
  
