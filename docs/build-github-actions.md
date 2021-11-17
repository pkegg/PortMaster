# GitHub Actions Builds
Builds run in GitHub Actions automatically on commits to `main` and for `PR`'s.

In order to speed up builds and prepare for a lot of custom builds in the future, it uses multiple builds to parallelize.

See: [build-parallel.yaml](../.github/workflows/build-parallel.yaml)