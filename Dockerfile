# Using CentOS 7 as base image to support rpmbuild (packages will be Dist el7)
FROM centos:7

# Copying all contents of rpmbuild repo inside container
COPY . .

# Installing tools needed for rpmbuild,
# depends on BuildRequires field in specfile, (TODO: take as input & install)
RUN rm -f /etc/yum.repos.d/CentOS-Media.repo
RUN yum install -y rpm-build rpmdevtools gcc make coreutils python git rsync yum-utils GeoIP-devel
#RUN yum install --enablerepo=* -y centos-release-scl-rh centos-release-scl
#RUN yum install --enablerepo=* -y rh-ruby23-rubygems
#RUN scl enable rh-ruby23 bash
#RUN gem install package_cloud

# run build script
ENTRYPOINT ["/build.sh"]
