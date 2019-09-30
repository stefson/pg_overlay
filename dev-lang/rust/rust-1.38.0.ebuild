# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

PYTHON_COMPAT=( python2_7 python3_{5,6,7} pypy )

inherit check-reqs estack flag-o-matic llvm multiprocessing multilib-build python-any-r1 rust-toolchain toolchain-funcs

if [[ ${PV} = *beta* ]]; then
	betaver=${PV//*beta}
	BETA_SNAPSHOT="${betaver:0:4}-${betaver:4:2}-${betaver:6:2}"
	MY_P="rustc-beta"
	SLOT="beta/${PV}"
	SRC="${BETA_SNAPSHOT}/rustc-beta-src.tar.xz"
else
	ABI_VER="$(ver_cut 1-2)"
	SLOT="stable/${ABI_VER}"
	MY_P="rustc-${PV}"
	SRC="${MY_P}-src.tar.xz"
	KEYWORDS="~amd64 ~arm64 ~ppc64 ~x86"
fi

RUST_STAGE0_VERSION="${PV}" #Use current version for stage0

DESCRIPTION="Systems programming language from Mozilla"
HOMEPAGE="https://www.rust-lang.org/"

SRC_URI="https://static.rust-lang.org/dist/${SRC} -> rustc-${PV}-src.tar.xz
	$(rust_all_arch_uris rust-${RUST_STAGE0_VERSION})"

ALL_LLVM_TARGETS=( AArch64 AMDGPU ARM BPF Hexagon Lanai Mips MSP430
	NVPTX PowerPC RISCV Sparc SystemZ WebAssembly X86 XCore )
ALL_LLVM_TARGETS=( "${ALL_LLVM_TARGETS[@]/#/llvm_targets_}" )
LLVM_TARGET_USEDEPS=${ALL_LLVM_TARGETS[@]/%/?}

LICENSE="|| ( MIT Apache-2.0 ) BSD-1 BSD-2 BSD-4 UoI-NCSA"

IUSE="clippy cpu_flags_x86_sse2 debug doc libressl rls rustfmt system-llvm wasm ${ALL_LLVM_TARGETS[*]}"

# Please keep the LLVM dependency block separate. Since LLVM is slotted,
# we need to *really* make sure we're not pulling more than one slot
# simultaneously.

# How to use it:
# 1. List all the working slots (with min versions) in ||, newest first.
# 2. Update the := to specify *max* version, e.g. < 9.
# 3. Specify LLVM_MAX_SLOT, e.g. 8.
LLVM_DEPEND="
	|| (
		sys-devel/llvm:9[llvm_targets_WebAssembly?]
		wasm? ( =sys-devel/lld-9* )
	)
	<sys-devel/llvm-10:=
"
LLVM_MAX_SLOT=9

COMMON_DEPEND="
	sys-libs/zlib
	!libressl? ( dev-libs/openssl:0= )
	libressl? ( dev-libs/libressl:0= )
	net-libs/libssh2
	net-libs/http-parser:=
	net-misc/curl[ssl]
	system-llvm? (
		${LLVM_DEPEND}
	)
"

DEPEND="${COMMON_DEPEND}
	${PYTHON_DEPS}
	|| (
		>=sys-devel/gcc-4.7
		>=sys-devel/clang-3.5
	)
	dev-util/cmake
"

RDEPEND="${COMMON_DEPEND}
	>=app-eselect/eselect-rust-20190311
	!dev-util/cargo
	rustfmt? ( !dev-util/rustfmt )
"

REQUIRED_USE="|| ( ${ALL_LLVM_TARGETS[*]} )
	wasm? ( llvm_targets_WebAssembly )
	x86? ( cpu_flags_x86_sse2 )
"
QA_FLAGS_IGNORED="usr/bin/* usr/lib*/${P}"

PATCHES=(
	"${FILESDIR}"/1.38.0-fix-custom-libdir.patch
	"${FILESDIR}"/1.38.0-fix-multiple-llvm-rebuilds.patch
	"${FILESDIR}"/rustc-1.38.0-rebuild-bootstrap.patch
	"${FILESDIR}"/0001-WIP-minimize-the-rust-std-component.patch
)

S="${WORKDIR}/${MY_P}-src"

toml_usex() {
	usex "$1" true false
}

pre_build_checks() {
	CHECKREQS_DISK_BUILD="9G"
	eshopts_push -s extglob
	if is-flagq '-g?(gdb)?([1-9])'; then
		CHECKREQS_DISK_BUILD="14G"
	fi
	eshopts_pop
	check-reqs_pkg_setup
}

pkg_pretend() {
	pre_build_checks
}

pkg_setup() {
	pre_build_checks
	python-any-r1_pkg_setup
	use system-llvm && llvm_pkg_setup
}

src_prepare() {
	local rust_stage0_root="${WORKDIR}"/rust-stage0

	local rust_stage0="rust-${RUST_STAGE0_VERSION}-$(rust_abi)"

	"${WORKDIR}/${rust_stage0}"/install.sh --disable-ldconfig --destdir="${rust_stage0_root}" --prefix=/ || die

	if use system-llvm; then
		rm -rf src/llvm-project/ || die
		# We never enable emscripten.
		rm -rf src/llvm-emscripten/ || die
	fi

	# Remove other unused vendored libraries            
	rm -rf vendor/curl-sys/curl/            
	rm -rf vendor/jemalloc-sys/jemalloc/            
	rm -rf vendor/libz-sys/src/zlib/            
	rm -rf vendor/lzma-sys/xz-*/            
	rm -rf vendor/openssl-src/openssl/

	# The configure macro will modify some autoconf-related files, which upsets
	# cargo when it tries to verify checksums in those files.  If we just truncate
	# that file list, cargo won't have anything to complain about.
	find vendor -name .cargo-checksum.json \
		-exec sed -i.uncheck -e 's/"files":{[^}]*}/"files":{ }/' '{}' '+'

	# Sometimes Rust sources start with #![...] attributes, and "smart" editors think
	# it's a shebang and make them executable. Then brp-mangle-shebangs gets upset...
	find -name '*.rs' -type f -perm /111 -exec chmod -v -x '{}' '+'

	default
}

src_configure() {
	local rust_target="" rust_targets="" arch_cflags

	# Collect rust target names to compile standard libs for all ABIs.
	for v in $(multilib_get_enabled_abi_pairs); do
		rust_targets="${rust_targets},\"$(rust_abi $(get_abi_CHOST ${v##*.}))\""
	done
	if use wasm; then
		rust_targets="${rust_targets},\"wasm32-unknown-unknown\""
	fi
	rust_targets="${rust_targets#,}"

	local extended="true" tools="\"cargo\","
	if use clippy; then
		tools="\"clippy\",$tools"
	fi
	if use rls; then
		tools="\"rls\",\"analysis\",\"src\",$tools"
	fi
	if use rustfmt; then
		tools="\"rustfmt\",$tools"
	fi

	local rust_stage0_root="${WORKDIR}"/rust-stage0

	rust_target="$(rust_abi)"

	cat <<- EOF > "${S}"/config.toml
		[llvm]
		optimize = $(toml_usex !debug)
		release-debuginfo = $(toml_usex debug)
		assertions = $(toml_usex debug)
		thin-lto = $(toml_usex system-llvm)
		targets = "${LLVM_TARGETS// /;}"
		experimental-targets = ""
		link-jobs = $(makeopts_jobs)
		link-shared = $(toml_usex system-llvm)
		use-libcxx = $(toml_usex system-llvm)
		use-linker = "$(usex system-llvm lld)"
		[build]
		build = "${rust_target}"
		host = ["${rust_target}"]
		target = [${rust_targets}]
		cargo = "/usr/bin/cargo"
		rustc = "/usr/bin/rustc"
		docs = $(toml_usex doc)
		compiler-docs = $(toml_usex doc)
		submodules = true
		fast-submodules = true
		python = "${EPYTHON}"
		locked-deps = false
		vendor = true
		full-bootstrap = true
		extended = ${extended}
		tools = [${tools}]
		verbose = 2
		sanitizers = false
		profiler = false
		local-rebuild = false
		[install]
		prefix = "${EPREFIX}/usr"
		libdir = "$(get_libdir)/${P}"
		docdir = "share/doc/${P}"
		mandir = "share/${P}/man"
		[rust]
		optimize = $(toml_usex !debug)
		debug = $(toml_usex debug)
		codegen-units-std = 1
		debug-assertions = $(toml_usex debug)
		debuginfo-level = 0
		backtrace = $(toml_usex debug)
		default-linker = "$(tc-getCC)"
		channel = "stable"
		rpath = false
		codegen-tests = $(toml_usex debug)
		dist-src = $(toml_usex debug)
		lld = $(toml_usex system-llvm)
		llvm-libunwind = $(toml_usex system-llvm)
	EOF

	for v in $(multilib_get_enabled_abi_pairs); do
		rust_target=$(rust_abi $(get_abi_CHOST ${v##*.}))
		arch_cflags="$(get_abi_CFLAGS ${v##*.})"

		cat <<- EOF >> "${S}"/config.env
			CFLAGS_${rust_target}=${arch_cflags}
		EOF

		cat <<- EOF >> "${S}"/config.toml
			[target.${rust_target}]
			cc = "x86_64-unknown-linux-gnu-$(tc-getBUILD_CC)"
			cxx = "x86_64-unknown-linux-gnu-$(tc-getBUILD_CXX)"
			linker = "x86_64-unknown-linux-gnu-$(tc-getCC)"
			ar = "$(tc-getAR)"
		EOF
		cat <<- EOF >> "${S}"/config.toml
			[host.${rust_target}]
			cc = "x86_64-unknown-linux-gnu-$(tc-getBUILD_CC)"
			cxx = "x86_64-unknown-linux-gnu-$(tc-getBUILD_CXX)"
			linker = "x86_64-unknown-linux-gnu-$(tc-getCC)"
			ar = "$(tc-getAR)"
		EOF
		if use system-llvm; then
			cat <<- EOF >> "${S}"/config.toml
				llvm-config = "$(get_llvm_prefix "${LLVM_MAX_SLOT}")/bin/llvm-config"
			EOF
		fi
	done

	if use wasm; then
		cat <<- EOF >> "${S}"/config.toml
			[target.wasm32-unknown-unknown]
			linker = "$(usex system-llvm lld rust-lld)"
		EOF
	fi
}

src_compile() {
	env $(cat "${S}"/config.env) \
		"${EPYTHON}" ./x.py build -vv --config="${S}"/config.toml -j$(makeopts_jobs) \
		--exclude src/tools/miri || die # https://github.com/rust-lang/rust/issues/52305
}

src_install() {
	local rust_target abi_libdir

	env DESTDIR="${D}" "${EPYTHON}" ./x.py install -vv --config="${S}"/config.toml \
	--exclude src/tools/miri || die

	mv "${ED}/usr/bin/rustc" "${ED}/usr/bin/rustc-${PV}" || die
	mv "${ED}/usr/bin/rustdoc" "${ED}/usr/bin/rustdoc-${PV}" || die
	mv "${ED}/usr/bin/rust-gdb" "${ED}/usr/bin/rust-gdb-${PV}" || die
	mv "${ED}/usr/bin/rust-gdbgui" "${ED}/usr/bin/rust-gdbgui-${PV}" || die
	mv "${ED}/usr/bin/rust-lldb" "${ED}/usr/bin/rust-lldb-${PV}" || die
	mv "${ED}/usr/bin/cargo" "${ED}/usr/bin/cargo-${PV}" || die
	if use clippy; then
		mv "${ED}/usr/bin/clippy-driver" "${ED}/usr/bin/clippy-driver-${PV}" || die
		mv "${ED}/usr/bin/cargo-clippy" "${ED}/usr/bin/cargo-clippy-${PV}" || die
	fi
	if use rls; then
		mv "${ED}/usr/bin/rls" "${ED}/usr/bin/rls-${PV}" || die
	fi
	if use rustfmt; then
		mv "${ED}/usr/bin/rustfmt" "${ED}/usr/bin/rustfmt-${PV}" || die
		mv "${ED}/usr/bin/cargo-fmt" "${ED}/usr/bin/cargo-fmt-${PV}" || die
	fi

	# Copy shared library versions of standard libraries for all targets
	# into the system's abi-dependent lib directories because the rust
	# installer only does so for the native ABI.
	for v in $(multilib_get_enabled_abi_pairs); do
		if [ ${v##*.} = ${DEFAULT_ABI} ]; then
			continue
		fi
		abi_libdir=$(get_abi_LIBDIR ${v##*.})
		rust_target=$(rust_abi $(get_abi_CHOST ${v##*.}))
		mkdir -p "${ED}/usr/${abi_libdir}/${P}"
		cp "${ED}/usr/$(get_libdir)/${P}/rustlib/${rust_target}/lib"/*.so \
		   "${ED}/usr/${abi_libdir}/${P}" || die
	done

	dodoc COPYRIGHT

	# FIXME:
	# Really not sure if that env is needed, specailly LDPATH
	cat <<-EOF > "${T}"/50${P}
		LDPATH="${EPREFIX}/usr/$(get_libdir)/${P}"
		MANPATH="${EPREFIX}/usr/share/${P}/man"
	EOF
	doenvd "${T}"/50${P}

	# note: eselect-rust adds EROOT to all paths below
	cat <<-EOF > "${T}/provider-${P}"
		/usr/bin/rustdoc
		/usr/bin/rust-gdb
		/usr/bin/rust-gdbgui
		/usr/bin/rust-lldb
	EOF
	echo /usr/bin/cargo >> "${T}/provider-${P}"
	if use clippy; then
		echo /usr/bin/clippy-driver >> "${T}/provider-${P}"
		echo /usr/bin/cargo-clippy >> "${T}/provider-${P}"
	fi
	if use rls; then
		echo /usr/bin/rls >> "${T}/provider-${P}"
	fi
	if use rustfmt; then
		echo /usr/bin/rustfmt >> "${T}/provider-${P}"
		echo /usr/bin/cargo-fmt >> "${T}/provider-${P}"
	fi
	dodir /etc/env.d/rust
	insinto /etc/env.d/rust
	doins "${T}/provider-${P}"
}

pkg_postinst() {
	eselect rust update --if-unset

	elog "Rust installs a helper script for calling GDB and LLDB,"
	elog "for your convenience it is installed under /usr/bin/rust-{gdb,lldb}-${PV}."

	ewarn "cargo is now installed from dev-lang/rust{,-bin} instead of dev-util/cargo."
	ewarn "This might have resulted in a dangling symlink for /usr/bin/cargo on some"
	ewarn "systems. This can be resolved by calling 'sudo eselect rust set ${P}'."

	if has_version app-editors/emacs || has_version app-editors/emacs-vcs; then
		elog "install app-emacs/rust-mode to get emacs support for rust."
	fi

	if has_version app-editors/gvim || has_version app-editors/vim; then
		elog "install app-vim/rust-vim to get vim support for rust."
	fi
}

pkg_postrm() {
	eselect rust cleanup
}
