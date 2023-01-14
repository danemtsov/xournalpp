#!/bin/bash

# Windows packaging script. This does the following:
# 0. Try to parse the last configured CMake build
# 1. Run "install" target from CMake into setup folder
# 2. Copy runtime dependencies into setup folder
# 3. Create version file and execute NSIS to create installer if not called with --portable option

echoerr() {
	>&2 echo -e -n "\e[1;31m"
	>&2 echo -n "$@"
	>&2 echo -e "\e[0m"
}
echowarn() {
	echo -e -n "\e[1;33m"
	echo -n "$@"
	echo -e "\e[0m"
}
echoinfo() {
	echo -e -n "\e[1;34m"
	echo -n "$@"
	echo -e "\e[0m"
}

# Directory of this script
script_dir=$(dirname $(readlink -f "$0"))

# Default values
create_installer=1
dry_run=0
cmake_command="cmake"
msys_env_root="/mingw64"
export pkg_source_dir=$(readlink -f "$script_dir/..")
export pkg_build_dir=$(readlink -f "../build")
export pkg_setup_dir="$script_dir/dist"

# Process arguments
while true; do
	case "$1" in
		"--portable") {
			echo "Won't create installer."
			create_installer=0
			shift
		};;
		"--dist-dir") {
			export pkg_setup_dir=$(readlink -f -- "$2" 2> /dev/null)
			if [ "$pkg_setup_dir" == "" ]; then
				echoerr "Invalid dist directory."
				exit 1
			fi
			shift 2
		};;
		"--dry-run") {
			echo "Dry run."
			dry_run=1
			shift
		};;
		"") break;;
		*) {
			echoerr "Unknown option: '$1'"
			exit 1
		}
	esac
done

# go to script directory
cd "$script_dir"

# Try to parse CMake build
if [ -f "./cmake/CMAKE_BINARY_DIR" ] && [ -f "./cmake/CMAKE_BUILD_TYPE" ] &&
		[ -f "./cmake/CMAKE_COMMAND" ] && [ -f "./cmake/CMAKE_CXX_COMPILER" ]; then
	echo "Found configured CMake build."
	cmake_build_type=$(<./cmake/CMAKE_BUILD_TYPE)
	if [ "$cmake_build_type" == "Debug" ]; then
		if [ $create_installer != 0 ]; then
			echoerr "Packaging Debug build into installer."
			exit 1
		else
			echowarn "Packaging Debug build."
		fi
	fi
	if tmp_root=$(cygpath "$(<./cmake/CMAKE_CXX_COMPILER)" | grep -E -o '^/[^/]+') && [ "$tmp_root" != "" ]; then
		if [ -n "${MSYSTEM+x}" ] && [ "/${MSYSTEM,,}" != "${tmp_root,,}" ]; then
			echoerr "MSYS environment root ($tmp_root) doesn't match current environment ($MSYSTEM)"
			exit 1
		fi
		msys_env_root=$tmp_root
	else
		echowarn "Couldn't parse MSYS environment root. Using $msys_env_root"
	fi
	cmake_command=$(cygpath "$(<./cmake/CMAKE_COMMAND)")
	export pkg_build_dir=$(cygpath "$(<./cmake/CMAKE_BINARY_DIR)")
else
	echowarn "CMake build seems not to be properly configured. Using defaults."
fi

echoinfo "Using MSYS env root:  \"$msys_env_root\""
echoinfo "Using CMake command:  \"$cmake_command\""
echoinfo "Using source folder:  \"$pkg_source_dir\""
echoinfo "Using build folder:   \"$pkg_build_dir\""
echoinfo "Using dist folder:    \"$pkg_setup_dir\""

if [ $dry_run != 0 ]; then
	exit
fi

# delete old setup, if there
echo "clean dist folder"
if ! ( rm -rf "$pkg_setup_dir" && rm -rf xournalpp-setup.exe ); then
	echoerr "Failed to clean dist folder."
	exit 1
fi

mkdir "$pkg_setup_dir"
mkdir "$pkg_setup_dir/lib"

echo "copy installed files"
if ! ( cd "$pkg_build_dir" && "$cmake_command" "$pkg_source_dir" -DCMAKE_INSTALL_PREFIX= &&
	DESTDIR="$pkg_setup_dir" "$cmake_command" --build . --target install ); then

	echoerr "CMake build failed."
	exit 1
fi

echo "copy libraries"
ldd "$pkg_build_dir/xournalpp.exe" | grep "$msys_env_root.*\\.dll" -o | sort -u | xargs -I{} cp "{}" "$pkg_setup_dir/bin/"
# CI workaround: copy libcrypto and libssl in case they are not already copied.
ldd "$pkg_build_dir/xournalpp.exe" | grep -E 'lib(ssl|crypto)[^\.]*\.dll' -o | sort -u | xargs -I{} cp "$msys_env_root/bin/{}" "$pkg_setup_dir/bin/"

# Copy system locale files
for trans in "$pkg_build_dir/po/*.gmo"; do
    # Bail if there are no translations at all
    [ -f "$trans" ] || break;

	# Retrieve locale from name of translation file
	locale=$(basename -s .gmo $trans)

	# GTK / GLib Translation
	cp -r /usr/share/locale/$locale/LC_MESSAGES/glib20.mo "$pkg_setup_dir/share/locale/$locale/LC_MESSAGES/glib20.mo"

	cp -r "$msys_env_root/share/locale/$locale/LC_MESSAGES/gdk-pixbuf.mo" "$pkg_setup_dir/share/locale/$locale/LC_MESSAGES/gdk-pixbuf.mo"
	cp -r "$msys_env_root/share/locale/$locale/LC_MESSAGES/gtk30.mo" "$pkg_setup_dir/share/locale/$locale/LC_MESSAGES/gtk30.mo"
	cp -r "$msys_env_root/share/locale/$locale/LC_MESSAGES/gtk30-properties.mo"	"$pkg_setup_dir/share/locale/$locale/LC_MESSAGES/gtk30-properties.mo"
done

echo "copy pixbuf libs"
cp -r "$msys_env_root/lib/gdk-pixbuf-2.0" "$pkg_setup_dir/lib/"

echo "copy pixbuf lib dependencies"
ldd "$msys_env_root/lib/gdk-pixbuf-2.0/2.10.0/loaders"/*.dll | grep "$msys_env_root.*\\.dll" -o | xargs -I{} cp "{}" "$pkg_setup_dir/bin/"

echo "copy icons"
cp -r "$msys_env_root/share/icons" "$pkg_setup_dir/share/"

echo "copy glib shared"
cp -r "$msys_env_root/share/glib-2.0" "$pkg_setup_dir/share/"

echo "copy poppler shared"
cp -r "$msys_env_root/share/poppler" "$pkg_setup_dir/share/"

echo "copy gtksourceview shared"
cp -r "$msys_env_root/share/gtksourceview-4" "$setup_dir/share"

echo "copy gspawn-win64-helper"
cp "$msys_env_root/bin/gspawn-win64-helper.exe" "$pkg_setup_dir/bin"
cp "$msys_env_root/bin/gspawn-win64-helper-console.exe" "$pkg_setup_dir/bin"

echo "copy gdbus"
cp "$msys_env_root/bin/gdbus.exe" "$pkg_setup_dir/bin"

if [ $create_installer != 0 ]; then
	echo "create installer"
	bash make_version_nsh.sh
	"/c/Program Files (x86)/NSIS/Bin/makensis.exe" xournalpp.nsi
fi

echo "finished"

