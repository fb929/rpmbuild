#!/bin/bash
PATH="/bin:/sbin:/usr/bin:/usr/sbin"

do_usage(){
    cat <<EOF
скрипт для сборки
умеет:
    1. пересобирать rpm-ки по build-репе
    2. пересобирать по Source RPM

rpmbuild/ пересоздаётся на каждый вызов $0
логи скрипта искать в ~/log/
EOF
    exit 1
}

# vars
SPEC_FILE=$(find /github/workspace/SPECS/ -type f -name "*.spec" | head -1)
BUILD_FROM_SPEC=true
CENTOS_RELEASE=7
TMP_DIR="$HOME/tmp"
RPMBUILD_DIR="$HOME/rpmbuild"
SOURCEDIR="$RPMBUILD_DIR/SOURCES"

# check {{
if ! [[ -s $SPEC_FILE ]]; then
    do_usage
fi
if echo $CENTOS_RELEASE | grep -vqP "^[0-9]+"; then
    echo "ERROR: bad format CENTOS_RELEASE=$CENTOS_RELEASE" 1>&2
    exit 1
fi
# }}

# init {{
if [[ -d $RPMBUILD_DIR ]]; then
    rm -rf $RPMBUILD_DIR
fi
install -d $TMP_DIR $RPMBUILD_DIR
install -d $RPMBUILD_DIR/{SOURCES,SPECS,SRPMS}
# }}

# sync rpmbuild dir {{
PATH_TO_REPO=$( dirname $SPEC_FILE | sed 's|/[A-Z]\+$||' )

if [[ -z $PATH_TO_REPO ]]; then
    echo "function usage: $FUNCNAME path/to/build-repo"
    exit 1
fi

# sync spec and sources
mkdir -p $PATH_TO_REPO/SOURCES/ # не обязательная директория
rsync -a --copy-links $PATH_TO_REPO/SPECS/ $RPMBUILD_DIR/SPECS/
rsync -a --copy-links $PATH_TO_REPO/SOURCES/ $RPMBUILD_DIR/SOURCES/
# }}

# new spec file
SPEC_FILE=$( find $RPMBUILD_DIR/SPECS/ -type f -name "*.spec" | head -1 )

# get sources
if spectool -g -R $SPEC_FILE; then
    # fix_archive_names {{
    IFS=$'\n'
    for LINE in $( grep -P "^Source[0-9]+:\s+http(s)?:.*#/" $SPEC_FILE | awk '{print $2}' ); do
        URL=$( echo $LINE | awk -F "#/" '{print $1}' )
        NAME=$( echo $LINE | awk -F "#/" '{print $2}' )
        VERSION_VAR=$( echo $NAME | sed 's|.*%{||; s|}.*||' )
        VERSION=$( grep -P "^%define\s+$VERSION_VAR\s+" $SPEC_FILE | awk '{print $NF}' )
        ARCH_NAME=$( echo $NAME | sed "s|%{$VERSION_VAR}|$VERSION|g" )
        if [[ -s $SOURCEDIR/v$VERSION ]]; then
            mv $SOURCEDIR/v$VERSION $SOURCEDIR/$ARCH_NAME
        fi
    done
    # }}
else
    echo "ERROR: failed get sources" 1>&2
    exit 1
fi

# build rpm {{
yum-builddep -y $SPEC_FILE
rpmbuild -ba $SPEC_FILE
EXIT_CODE=$?
if [[ $EXIT_CODE != 0 ]]; then
    echo "ERROR: failed run 'rpmbuild -ba $SPEC_FILE'" 1>&2
    exit 1
fi
# }}

# move rpms and create checksum
mv $RPMBUILD_DIR/SRPMS/* $HOME/
mv $RPMBUILD_DIR/RMPS/*/* $HOME/
md5sum *.rpm > md5sum
sha256sum *.rpm > sha256sum

## generate artifacts {{
#ARTIFACTS=""
#for PKG in $(find $RPMBUILD_DIR/{SRPMS,RPMS}/ -type f ); do
#    PKG_PATH=$( echo "$PKG" | sed "s|^$RPMBUILD_DIR/||" )
#    PKG_NAME=$( basename $PKG )
#    #ARTIFACTS=${ARTIFACTS}\"$PKG\",\ 
#    LINE={ \"path\": \"$PKG\" , \"name\": \"$PKG_NAME\" }
#    if [[ -z $ARTIFACTS ]]; then
#        ARTIFACTS=$LINE
#    else
#        ARTIFACTS=${ARTIFACTS}, $LINE
#    fi
#done
##echo name=matrix::{\"file\": [${ARTIFACTS} \"md5sum\"]}
##echo ::set-output name=matrix::{\"file\": [${ARTIFACTS} \"md5sum\"]}
##echo "::set-output name=matrix::{\"include\":[{\"project\":\"foo\",\"config\":\"Debug\"},{\"project\":\"bar\",\"config\":\"Release\"}]}"
#echo name=matrix::{\"include\":[ $ARTIFACTS ]}
#echo ::set-output name=matrix::{\"include\":[ $ARTIFACTS ]}
## }}
