# tldr;
Try this on linux:
- Clone this repo
- install [docker](https://docs.docker.com/get-docker/)
  - check install with: `./init-docker`
- Build a port with: `./build <port name>`
- Commit something and watch GitHub Actions build automatically.

# What is this 'build/package' stuff about?
- Commit a change and all ports and portmaster will be automatically built/packaged/published via GitHub Actions/Docker.
- Lean into this automation to: reuse code across ports, standardize build and packaging of ports.
- Ensure devs can still easily manually build/tweak ports without Docker/GitHub actions.

## build/package a port - docker
- install [docker](https://docs.docker.com/get-docker/)
- check install with: `./init-docker`
- `./build <port name>`

## build/package a port - using ARM chroot - no docker
Though using docker is recommended, many have been building in a debian arm chroot.  This is still supported.  Just run:
- `./build <port name>` or `./build <port name> --install-deps` (uses apt-get to install depedencies if they are needed for a package).
  - `./ports/install-deps` - will install global depedencies initially
  - If a port/package does not have a `build` script (as it downloads precompiled/legacy binaries, etc), any architecture is supported.
  - Docker can be explicitly disabled with `--no-docker`, ex: `./build <package> --no-docker`.  It will use this mode (with a warning) if no docker binary is found.

# Can I cross compile for faster builds and no gross qemu?
Yes.  Though there's not a package that does this yet, and it will be setup on a package by package basic.  To cross-compile, just setup the `BUILD_PLATFORM=linux/amd64` in `package.info` and ensure the `ports/<package>/build` script is setup to cross-compile using CMake or however the package is built.  Then `./build <package>` and everything should work.

# Overview
Below find the design around expanding PortMaster to include the ability to build, package and automatically publish ports.

## Problem Statements
Initially, PortMaster left the build and packaging entirely up to the port maintainer and committed zips directly into GitHub.  Though this is simple and can work well given a limited number of port maintainers, it has a few drawbacks which we aim to address:
- **No start script reuse** - PortMaster aims to support many different devices, but when device specific code is needed to launch a script, that code gets duplicated across all ports.  Bugs in a given bit of code need to be fixed in 50+ port zips.  
  - Even for code that is bug-free, code is often not clear due to lack of function reuse.  For example: `if [[ -e "/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick" ]]; then` really means `if anbernic rg351v or rg351p"`, but unless you are familiar with the kernel layout of anbernic devices, you are unlikely to know that.
  - `Fix`: Provide a `global-functions.sh` file which will be copied automatically into every port with common functions.  Ensure it's automatically tested.  
- **No record of how to build/package** - If a port maintainer stops contributing (or forgets how they built), there is no easy way to recreate build artifacts.  At a minimum, this can make it difficult to upgrade ports.
  - `Fix`: Create a `package.info` key/value file with info about where to download the port sources.  Allow each port to provide a: `build` script that knows how to build the downloaded sources. 
- **No Automation** - Though christian tirelessly updates the ports, it takes some of his time.  Ideally, ports could be published automatically or with just a click
  - `Fix`: Use docker + github actions to run the builds on commit. Cache builds in github's docker registry so only changed ports are fully 'rebuilt'.
- **GitHub binary size limitations** - The ports are currently checked into GitHub.  This is simple, but has the disadvantage that ports over 100MB are not supported and much be hosted somewhere else.
  - `Fix`: Move to using GitHub releases to host port zips.  There is no size limitation.
- **No off device testing** - PortMaster is simple to manually test and update on a supported device.  However, it is painful to do all development that way and makes automated testing almost impossible.
  - `Fix`: Use `global-function` refactoring to simplify the main portmaster script and add 'console' detection that can output `dialog` to stdout for testing off device and automated testing.

## Enhancements to PortMaster
This change introduces a /ports directory to the PortMaster repo.  Each port should be a lower case folder name for consistency.  

### Backwards Compatibility
The simplest version of a port just downloads the old PortMaster zip for that port and repackages it.  This results in an **identical** zip (with the additional of global-functions and updated oga_controls) but the zip can be built/cached/published using the new approach.

Ex: `/ports/cannonball/package.info`

```
PKG_NAME="Cannonball"
LEGACY_PORTMASTER="true"
```


# Build Scripts Overview
There are three modes which ports can be built.
- `normal/docker container` (`./buld <port>`) - uses Dockerfiles to provide build environment and runs the actual build via a docker container.
  - Uses: /<port>/install-deps to provide environment
  - Advantages (good for most users)
    - All build dependencies stored in docker.  But builds very similarly to a local build.
    - Can use CCache or other cache to speed incremental builds.
  - Disadvantages
    - Requires full build on initial checkout - which is not ideal for a ephemeral build server like GitHub actions.
- `docker-image` (`./build <port> --docker-image`) - similar to normal, but builds inside of a docker image (Dockerfile) instead of a docker container.  This allows caching/publishing the full build caching/reuse by the build server.
  - Uses: Dockerfile.build.template which will be copied to <port>/Dockerfile.build to run build inside the Dockerfile
  - Advantages (good for cloud builds): 
    - If build has not changed, uses remote cache.
    - Does not require local build cache.  Makes it possible to run in GitHub actions and still only building new changes.
  - Disadvantages:
    - If anything changes, a full build of port is required.  CCache or other cache cannot be used to speed up rebuilds. 
- `no docker` (`./build <port> --no-docker`) - basically for debugging.  Does not use docker and assumes all dependencies, architecture, etc are in host.

Other build scripts:
- `build-all` - calls `build` for all ports (folders with package.info)
- `build-base-image` - builds the top level `Dockerfile` (build environment), `Dockerfile.build` (build env + build scripts to run build inside a Dockerfile) and runs testing on global-functions scripts.
- `clone-source` - script used to do git clones.  This is separated as it is the only build script used inside the docker image when building with `--docker-image` (which means a change will rebuild all ports)

# Port Requirements
The following shows conventions and requirements for port builds and packaging (run on device).
## Build
The following files can be used to build a port.
- `<port folder>` - must be lower case and valid in a docker tag (lower case)
- `package.info` (Required) - provides information about the package and it's source.
   - NOTE: this is similar to the EmuELEC package.mk format.  It is called package.info to show its not totally compatible.
  - `PKG_NAME` - The name of the package.  Can include spaces.  Will be used for name of zip and main script.
  - `PKG_URL` - The source code url.  Will be cloned into `source`. Smart enough to do a `git pull` if already exists.
  - `PKG_VERSION` - the version of source code - typically git hash or tag.  NOTE: though branch is technically allowed, it is not 'supported' as the package will not be rebuilt unless something changes in the ports directory.
  - `HANDLER_SUPPORT` - currently only `git` is supported. Can be left off if no PKG_URL and defaults to git.
- `Dockerfile` - provides any addition dependencies for build beyond main Dockerfile
- `build` - script to run build.
  - Will be run from `source` directory if one was created or the port directory if one does not exist.
  - The script can output build artifacts to the `pkg` directory.  For longer builds or complex packaging logic, it is suggested to use a `package` script.  This allows faster rebuilds on packaging changes even in the cloud.
  - NOTE: Will be run with bash if not set as executable.
- `package` - script to package build.
  - Will be run from the port directory.
  - Must only utilize source, pkg and committed files.
# Build Use Cases
- developer needs to build
  - ./build <package>
    - Builds with portmaster:main container -> package container portmaster/<package>:main
      - uses local build script.  Incremental builds, ccache, etc, possible
  - ./build --docker-image <package>
    - Builds with portmaster:main container -> package container portmaster/<package>:main
      - uses build script embedded in container.  Incremental builds not possible.
  - ./build --docker-image --no-cache <package>
      - allows re-doing a build in case there are issues in cache
  - ./build-all - mostly for testing.  Not strictly required
  - ./build-base-image --platform <one platform> - testing library updates.  Should load image into docker so other builds use this image.

- developer needs to package/run
   - ability to choose BUILD_ARCH so cross compiling is optional (linux/arm/v7, linux/arm64/v8, linux/amd64)
     - this allows speeding things up if linux/amd64 + cross compile used
   - ability to add additional libraries (Dockerfile)
   - ability to add portmaster functions to not duplicate device detection, etc, across of devices

- portmaster needs
  - portmaster should be 'just another port (tm)'
  - injection of branch?
    - resolution of latest 'release' for that branch if one exists?

- build server needs
  - ./build-all --docker-image --push
    - needs caching (as compiling everything would take hours)
       - Should build and push a container for each port which contains the built files so compilation is fast, but is redone on changes
  - ./build --docker-image --push
    - Manual action kicked off for a single build to re-run.  Maybe 'no-cache' option too.
  - ./build-base-image --platform all --push
    - Due to docker build container limitations **all** cannot be used without --push
      - we could implement with three docker build calls for each platform, but seems a PITA
