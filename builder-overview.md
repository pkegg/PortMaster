# Users
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