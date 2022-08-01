# rpmbuild
## usage
```
mkdir -p .github/workflows
cat <<EOF > .github/workflows/release.yml
---
name: rpm build and release

on:
  release:
    types:
      - published

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.build.outputs.matrix }}
    steps:
      - name: check out repository code
        uses: actions/checkout@v3

      - name: build RPM package
        id: build
        uses: fb929/rpmbuild@master

      - name: upload artifact
        uses: actions/upload-artifact@v2
        with:
          name: packages
          retention-days: 1
          path: |
            /home/runner/work/_temp/_github_home/*.rpm
            /home/runner/work/_temp/_github_home/sha256sum
            /home/runner/work/_temp/_github_home/md5sum
  upload:
    needs: build
    runs-on: ubuntu-latest
    strategy:
      matrix: ${{fromJson(needs.build.outputs.matrix)}}
    steps:
      - name: download artifact
        uses: actions/download-artifact@v2
        with:
          name: packages
      - name: upload ${{ matrix.file }}
        id: upload
        uses: actions/upload-release-asset@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          upload_url: ${{ github.event.release.upload_url }}
          asset_path: ${{ matrix.file}}
          asset_name: ${{ matrix.file}}
          asset_content_type: application/octet-stream
EOF
