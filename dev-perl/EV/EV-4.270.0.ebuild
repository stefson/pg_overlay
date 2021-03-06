# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DIST_AUTHOR=MLEHMANN
DIST_VERSION=4.27
inherit perl-module

DESCRIPTION="Perl interface to libev, a high performance full-featured event loop"

SLOT="0"
KEYWORDS="amd64 ~arm ppc ppc64 x86"
IUSE=""

RDEPEND="
	dev-perl/common-sense
"
DEPEND="${RDEPEND}
	virtual/perl-ExtUtils-MakeMaker
	dev-perl/Canary-Stability
"
