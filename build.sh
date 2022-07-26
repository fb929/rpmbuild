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
логи mock в ~/tmp/result/<профиль mock>
EOF
	exit 1
}

# vars
SPEC_FILE=$(find /github/workspace/SPECS/ -type f -name "*.spec" | head -1)
echo SPEC_FILE=$SPEC_FILE
BUILD_FROM_SPEC=true
MOCK_PROFILE="mock-centos-7-x86_64"
CENTOS_RELEASE=7
LOG_DIR="$HOME/log"
LOG_FILE="$LOG_DIR/$( basename $0 ).log"
TMP_DIR="$HOME/tmp"
RPMBUILD_DIR="$HOME/rpmbuild"
SOURCEDIR="$RPMBUILD_DIR/SOURCES"
RPMS_DIR="/var/lib/repo"
MOCK_DIR="$TMP_DIR/mock/$MOCK_PROFILE"
RESULT_DIR="$TMP_DIR/result/$MOCK_PROFILE"

# check
if ! [[ -s $SPEC_FILE ]]; then
	do_usage
fi
if echo $CENTOS_RELEASE | grep -vqP "^[0-9]+"; then
	echo "ERROR: bad format CENTOS_RELEASE=$CENTOS_RELEASE"
	exit 1
fi

# func
do_init(){
	# create dirs
	if [[ -d $RPMBUILD_DIR ]]; then
		rm -rf $RPMBUILD_DIR
	fi
	install -d $LOG_DIR $TMP_DIR $RPMBUILD_DIR $RESULT_DIR
	install -d $RPMBUILD_DIR/{SOURCES,SPECS,SRPMS}
}
do_sync_rpmbuild_dir(){
	local PATH_TO_REPO=$1

	if [[ -z $PATH_TO_REPO ]]; then
		echo "function usage: $FUNCNAME path/to/build-repo"
		exit 1
	fi

	# sync spec and sources
	mkdir -p $PATH_TO_REPO/SOURCES/ # не обязательная директория
	rsync -a --copy-links $PATH_TO_REPO/SPECS/ $RPMBUILD_DIR/SPECS/
	rsync -a --copy-links $PATH_TO_REPO/SOURCES/ $RPMBUILD_DIR/SOURCES/
}
do_fix_archive_names(){
	local SPEC_FILE=$1
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
}
do_build_source_rpm(){
	# get sources and build srpm
	if spectool -g -R $SPEC_FILE &>> $LOG_FILE; then
		do_fix_archive_names $SPEC_FILE
		#mock --root $MOCK_PROFILE --rootdir=$MOCK_DIR --resultdir=$RESULT_DIR --buildsrpm --spec $SPEC_FILE --sources $RPMBUILD_DIR/SOURCES
		SRPM_FILE=$( rpmbuild -bs $SPEC_FILE 2>> $LOG_FILE | grep -P "srpm|src\.rpm" | tail -1 | awk '{print $NF}' )
		if ! [[ -s $SRPM_FILE ]]; then
			echo "ERROR: failed build srpm file"
			exit 1
		fi
	else
		echo "ERROR: failed get sources"
		exit 1
	fi
}
do_build_rpm(){
	# build rpms
	if [[ -s $SRPM_FILE ]]; then
		INFO=$( rpm -qip $SRPM_FILE )
		RPM_NAME=$( echo "$INFO" | grep -P '^Name\s+:' | awk '{print $NF}' )
		RPM_VERSION=$( echo "$INFO" | grep -P '^Version\s+:' | awk '{print $NF}' )
		mock --root $MOCK_PROFILE --rootdir=$MOCK_DIR --resultdir=$RESULT_DIR $SRPM_FILE &> $LOG_DIR/mock.log
		EXIT_CODE=$?
		if [[ $EXIT_CODE != 0 ]]; then
			echo "ERROR: failed mock run, see $LOG_DIR/mock.log"
			exit 1
		fi
	else
		echo "ERROR: filed get srpm file"
		exit 1
	fi
}
do_sync_local(){
	# sync rpm to local repo
	install --mode=0775 --group=mock --directory $RPMS_DIR
	RPMS=$( ls $RESULT_DIR/${RPM_NAME}*${RPM_VERSION}*.rpm )
	for RPM in $RPMS; do
		ARCH=$( echo $RPM | sed 's|\.rpm||' | awk -F "." '{print $NF}' )
		case $ARCH in
			src) ARCH="SRPMS";;
			*) ARCH="x86_64";;
		esac
		install --mode=0775 --group=mock --directory $RPMS_DIR/$CENTOS_RELEASE/$ARCH
		rsync -a $RPM $RPMS_DIR/$CENTOS_RELEASE/$ARCH/
	done
	for ARCH in $( ls $RPMS_DIR/$CENTOS_RELEASE/ ); do
		createrepo_c $RPMS_DIR/$CENTOS_RELEASE/$ARCH &>> $LOG_DIR/createrepo.log
	done
}

# action
do_init
if $BUILD_FROM_SPEC; then
	do_sync_rpmbuild_dir $( dirname $SPEC_FILE | sed 's|/[A-Z]\+$||' )
	do_build_source_rpm
fi
do_build_rpm
#do_sync_local
