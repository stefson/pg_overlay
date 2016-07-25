# Copyright 1999-2016 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Id$

EAPI=6
GNOME2_LA_PUNT="yes"

inherit autotools gnome2

SRC_URI="https://github.com/linuxmint/${PN}/archive/${PV}.tar.gz"
DESCRIPTION="A simple and easy to use image viewer. X-Apps Project"
HOMEPAGE=""

LICENSE="GPL-2+"
SLOT="1"

IUSE="debug +exif +introspection +jpeg lcms +svg tiff xmp"
REQUIRED_USE="exif? ( jpeg )"

KEYWORDS="~alpha ~amd64 ~arm ~ia64 ~ppc ~ppc64 ~sparc ~x86 ~x86-fbsd"

RDEPEND="
	>=dev-libs/glib-2.42.0:2[dbus]
	>=dev-libs/libpeas-0.7.4:=[gtk]
	>=gnome-extra/cinnamon-3.0.0
	>=x11-libs/gtk+-3.19.3:3[introspection,X]
	>=x11-misc/shared-mime-info-0.20

	>=x11-libs/gdk-pixbuf-2.30.0:2[jpeg?,tiff?]
	x11-libs/libX11

	exif? ( >=media-libs/libexif-0.6.14 )
	introspection? ( >=dev-libs/gobject-introspection-0.9.3:= )
	jpeg? ( virtual/jpeg:0 )
	lcms? ( media-libs/lcms:2 )
	svg? ( >=gnome-base/librsvg-2.36.2:2 )
	xmp? ( media-libs/exempi:2 )
"
DEPEND="${RDEPEND}
	>=dev-util/gtk-doc-am-1.16
	>=dev-util/intltool-0.50.1
	dev-util/itstool
	sys-devel/gettext
	virtual/pkgconfig
"
src_prepare() {
	autoreconf
}
src_configure() {
	gnome2_src_configure \
		$(usex debug --enable-debug=yes ' ') \
		$(use_enable introspection) \
		$(use_with jpeg libjpeg) \
		$(use_with exif libexif) \
		$(use_with lcms cms) \
		$(use_with xmp) \
		$(use_with svg librsvg)
}
