# Distributed under the terms of the GNU General Public License v2

EAPI="6"

inherit gnome2 meson multilib-minimal

DESCRIPTION="GTK+ & GNOME Accessibility Toolkit"
HOMEPAGE="https://wiki.gnome.org/Accessibility"

LICENSE="LGPL-2+"
SLOT="0"
KEYWORDS="*"

IUSE="doc +introspection nls"

RDEPEND="
	>=dev-libs/glib-2.32:2[${MULTILIB_USEDEP}]
	introspection? ( >=dev-libs/gobject-introspection-1.32.0:= )
"
DEPEND="${RDEPEND}
	>=dev-lang/perl-5
	>=dev-util/gtk-doc-am-1.25
	>=virtual/pkgconfig-0-r1[${MULTILIB_USEDEP}]
	nls? ( >=sys-devel/gettext-0.19.2 )
"

multilib_src_configure() {
	local emesonargs=(
		-D docs=$(usex doc true false)
		-D introspection=$(usex introspection true false)
	)
	meson_src_configure
}

multilib_src_compile() {
	meson_src_compile
}

multilib_src_install() {
	meson_src_install

	# This autogenerated header includes multilib-specific full paths
	# from build which break the multilib header comparison, so remove
	# the multilib-specific base part of the path from the comments.
	sed -e 's:enumerations from "[^"]*\.\./[^/]*/:enumerations from ":' \
	    -i "${D}/usr/include/atk-1.0/atk/atk-enum-types.h"
}
