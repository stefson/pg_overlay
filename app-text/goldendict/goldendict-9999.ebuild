# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7
PLOCALES="ar_SA ay_WI be_BY be_BY@latin bg_BG cs_CZ de_DE el_GR eo_EO es_AR es_BO es_ES fa_IR fi_FI fr_FR hi_IN it_IT ja_JP ko_KR lt_LT mk_MK nl_NL pl_PL pt_BR qt_es qt_it qt_lt qu_WI ru_RU sk_SK sq_AL sr_SR sv_SE tg_TJ tk_TM tr_TR uk_UA vi_VN zh_CN zh_TW"

inherit desktop eutils qmake-utils git-r3 l10n

DESCRIPTION="Feature-rich dictionary lookup program"
HOMEPAGE="http://goldendict.org/"
EGIT_REPO_URI="https://github.com/goldendict/goldendict.git"

LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="debug ffmpeg libav"

RDEPEND="
	app-arch/bzip2
	>=app-text/hunspell-1.2:=
	dev-libs/eb
	dev-libs/lzo
	dev-qt/qtcore:5
	dev-qt/qtgui:5
	dev-qt/qthelp:5
	dev-qt/qtnetwork:5
	dev-qt/qtprintsupport:5
	dev-qt/qtsql:5
	dev-qt/qtsvg:5
	dev-qt/qtwebkit:5
	dev-qt/qtwidgets:5
	dev-qt/qtx11extras:5
	dev-qt/qtxml:5
	media-libs/libvorbis
	media-libs/tiff:0
	sys-libs/zlib
	x11-libs/libX11
	x11-libs/libXtst
	ffmpeg? (
		media-libs/libao
		libav? ( media-video/libav:0= )
		!libav? ( media-video/ffmpeg:0= )
	)
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-qt/linguist-tools:5
	virtual/pkgconfig
"

src_prepare() {
	default

	# disable git
	sed -i \
		-e '/git describe/s/^/#/' \
		${PN}.pro || die

	# fix installation path
	sed -i \
		-e '/PREFIX = /s:/usr/local:/usr:' \
		${PN}.pro || die

	# add trailing semicolon
	sed -i -e '/^Categories/s/$/;/' redist/${PN}.desktop || die

	echo "QMAKE_CXXFLAGS_RELEASE = $CXXFLAGS" >> ${PN}.pro
	echo "QMAKE_CFLAGS_RELEASE = $CFLAGS" >> ${PN}.pro

	local loc_dir="${S}/locale"
	l10n_find_plocales_changes "${loc_dir}" "" ".ts"
	rm_loc() {
		rm -vf "locale/${1}.ts" || die
		sed -i "/${1}.ts/d" ${PN}.pro || die
	}
	l10n_for_each_disabled_locale_do rm_loc
}

src_configure() {
	local myconf=()

	if ! use ffmpeg && ! use libav ; then
		myconf+=( CONFIG+=no_ffmpeg_player )
	fi

	myconf+=( CONFIG+=no_qtmultimedia_player )
	eqmake5 "${myconf[@]}" ${PN}.pro
}

install_locale() {
	insinto /usr/share/apps/${PN}/locale
	doins "${S}"/locale/${1}.qm
	eend $? || die "failed to install $1 locale"
}

src_install() {
	dobin ${PN}
	domenu redist/${PN}.desktop
	doicon redist/icons/${PN}.png

	insinto /usr/share/${PN}/help
	doins help/gdhelp_en.qch
	l10n_for_each_locale_do install_locale
}
