#***************************************************************************
#                                  _   _ ____  _
#  Project                     ___| | | |  _ \| |
#                             / __| | | | |_) | |
#                            | (__| |_| |  _ <| |___
#                             \___|\___/|_| \_\_____|
#
# Copyright (C) Daniel Stenberg, <daniel@haxx.se>, et al.
#
# This software is licensed as described in the file COPYING, which
# you should have received as part of this distribution. The terms
# are also available at https://curl.se/docs/copyright.html.
#
# You may opt to use, copy, modify, merge, publish, distribute and/or sell
# copies of the Software, and permit persons to whom the Software is
# furnished to do so, under the terms of the COPYING file.
#
# This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
# KIND, either express or implied.
#
# SPDX-License-Identifier: curl
#
###########################################################################

AUTOMAKE_OPTIONS = foreign no-dependencies

MANPAGE = curl.1
ASCIIPAGE = curl.txt

man_MANS = $(MANPAGE)

include Makefile.inc

EXTRA_DIST = $(DPAGES) MANPAGE.md gen.pl $(SUPPORT) CMakeLists.txt mainpage.idx

GEN = $(GN_$(V))
GN_0 = @echo "  GENERATE" $@;
GN_1 =
GN_ = $(GN_0)

if BUILD_DOCS
CLEANFILES = $(MANPAGE) $(ASCIIPAGE)

all: $(MANPAGE) $(ASCIIPAGE)

endif

$(MANPAGE): $(DPAGES) $(SUPPORT) mainpage.idx Makefile.inc gen.pl
	$(GEN)(rm -f $(MANPAGE) && (cd $(srcdir) && @PERL@ ./gen.pl mainpage $(DPAGES)) > manpage.tmp.$$$$ && mv manpage.tmp.$$$$ $(MANPAGE))

$(ASCIIPAGE): $(DPAGES) $(SUPPORT) mainpage.idx Makefile.inc gen.pl
	$(GEN)(rm -f $(ASCIIPAGE) && (cd $(srcdir) && @PERL@ ./gen.pl ascii $(DPAGES)) > asciipage.tmp.$$$$ && mv asciipage.tmp.$$$$ $(ASCIIPAGE))

listhelp:
	./gen.pl listhelp $(DPAGES) > $(top_builddir)/src/tool_listhelp.c
