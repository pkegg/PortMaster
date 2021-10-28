# tldr; - build a port
- install [docker](https://docs.docker.com/get-docker/)
- check install with: `./init-docker`
- `./build <port name>`

# Build Scripts Overview
There are three modes which ports can be built.
- `normal` (`./buld <port>`) - uses Dockerfiles to provide build environment via docker container.
  - Uses: /<port>/Dockerfile to provide environment
  - Advantages (good for users)
    - All build dependencies stored in docker.  But builds very similarly to a local build.
    - Can use CCache or other cache to speed incremental builds.
  - Disadvantages
    - Requires full build initially which is not ideal for a ephemeral build server like GitHub actions.
- `docker-image` (`./build <port> --docker-image`) - similar to normal, but builds inside of a docker image.  Allows caching/publishing image for build server.
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