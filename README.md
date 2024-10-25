# rpmbuild
## usage
### create file .github/workflows/release.yml with content:
```
---
on:
  push:
    # Sequence of patterns matched against refs/tags
    tags:
      - '*' # Push any events

name: release

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        platform:
          - linux/amd64
          - linux/arm64
    steps:
      - name: check out repository code
        uses: actions/checkout@v3

      - name: build RPM package
        id: build
        uses: fb929/rpmbuild@v1
        with:
          platform: ${{ matrix.platform }}

      # create release and upload assets
      - name: Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
          prerelease: true
          files: |
            ./result/*.rpm
            ./result/*.sha256sum
            ./result/*.md5sum
```
### create dirs SOURCES,SPECS and spec file SPECS/myspec.spec
