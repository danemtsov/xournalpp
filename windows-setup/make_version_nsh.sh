#!/usr/bin/env bash

if [ -z ${pkg_build_dir+x} ]; then
    echo pkg_build_dir is not set; using default.
    pkg_build_dir=../build
fi

version=$(cat "$pkg_build_dir/VERSION" | sed '1!d')
cat << EOF > xournalpp_version.nsh
!define XOURNALPP_VERSION "$version"
EOF