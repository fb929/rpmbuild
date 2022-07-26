# Using CentOS 7 as base image to support rpmbuild (packages will be Dist el7)
FROM centos:7

# Copying all contents of rpmbuild repo inside container
COPY . .

# Installing tools needed for rpmbuild,
# depends on BuildRequires field in specfile, (TODO: take as input & install)
RUN yum install -y rpm-build rpmdevtools gcc make coreutils python git mock rsync

RUN cp /mock-centos-7-x86_64.cfg /etc/mock/
# run build script
ENTRYPOINT ["/build.sh"]
