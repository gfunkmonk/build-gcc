cd "${BASE}/build/" || exit 1

# build GNU sed if needed.
if [ ! -z "${SED_VERSION}" ]; then
  if [ ! "$(cat ${TMPINST}/sed-version 2> /dev/null)" == "${SED_VERSION}" ]; then
    echo "Building sed"
    untar "$SED_ARCHIVE" || exit 1
    cd "sed-${SED_VERSION}/"
    TEMP_CFLAGS="$CFLAGS"
    TEMP_CPPFLAGS="$CPPFLAGS"
    export CFLAGS="${CFLAGS//-w}"   # configure fails if warnings are disabled.
    # sed uses a non-recursive make, so lib/ files are compiled from the top
    # directory.  The gnulib-provided obstack.h lives in lib/ and won't be
    # found via the default include path on systems (e.g. macOS) that lack a
    # system obstack.h.  Add lib/ explicitly so <obstack.h> resolves correctly.
    export CPPFLAGS="$CPPFLAGS -I$(pwd)/lib"
    # Prevent gnulib from falsely detecting MSVC-specific types on non-Windows
    # hosts (e.g. macOS whose SDK exposes _invalid_parameter_handler).
    gl_cv_type_invalid_parameter_handler=no \
    ./configure --prefix="$TMPINST" ${BUILD_FLAG} ${HOST_FLAG} || exit 1
    ${MAKE_J} || exit 1
    ${MAKE_J} DESTDIR= install || exit 1
    CFLAGS="$TEMP_CFLAGS"
    CPPFLAGS="$TEMP_CPPFLAGS"
    echo ${SED_VERSION} > "${TMPINST}/sed-version"
  fi
fi

WITH_LIBS=""

build_lib()
{
  local name="$1"
  shift
  local display_name="${name^^}"
  local archive_var="${name^^}_ARCHIVE"
  local version_var="${name^^}_VERSION"
  local archive="${!archive_var}"
  local version="${!version_var}"
  if [ ! -z "$version" ]; then
    if [ "$(cat ${TMPINST}/${name}-version 2> /dev/null)" != "$version" ]; then
      echo "Building $display_name $version"
      cd ${BASE}/build || exit 1
      untar "$archive" || exit 1
      cd "${name}-${version}/" || exit 1
      ./configure --prefix="$TMPINST" --disable-shared "$@" || exit 1
      ${MAKE_J} || exit 1
      ${MAKE_J} DESTDIR= install || exit 1
      echo $version > "${TMPINST}/${name}-version"
    fi

    WITH_LIBS+=" --with-${name}=$TMPINST"
  fi
}

CFLAGS+=" -std=gnu17" build_lib gmp
build_lib mpfr --with-gmp="$TMPINST"
build_lib mpc --with-gmp="$TMPINST" --with-mpfr="$TMPINST"
build_lib isl --with-gmp=system --with-gmp-prefix="$TMPINST"
