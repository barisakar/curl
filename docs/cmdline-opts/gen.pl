#!/usr/bin/env perl
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

=begin comment

This script generates the manpage.

Example: gen.pl <command> [files] > curl.1

Dev notes:

We open *input* files in :crlf translation (a no-op on many platforms) in
case we have CRLF line endings in Windows but a perl that defaults to LF.
Unfortunately it seems some perls like msysgit cannot handle a global input-only
:crlf so it has to be specified on each file open for text input.

=end comment
=cut

my %optshort;
my %optlong;
my %helplong;
my %arglong;
my %redirlong;
my %protolong;
my %catlong;

use POSIX qw(strftime);
my @ts;
if (defined($ENV{SOURCE_DATE_EPOCH})) {
    @ts = localtime($ENV{SOURCE_DATE_EPOCH});
} else {
    @ts = localtime;
}
my $date = strftime "%B %d %Y", @ts;
my $year = strftime "%Y", @ts;
my $version = "unknown";
my $globals;

open(INC, "<../../include/curl/curlver.h");
while(<INC>) {
    if($_ =~ /^#define LIBCURL_VERSION \"([0-9.]*)/) {
        $version = $1;
        last;
    }
}
close(INC);

# get the long name version, return the man page string
sub manpageify {
    my ($k)=@_;
    my $l;
    my $trail;
    # the matching pattern might include a trailing dot that cannot be part of
    # the option name
    if($k =~ s/\.$//) {
        # cut off trailing dot
        $trail = ".";
    }
    my $klong = $k;
    # quote "bare" minuses in the long name
    $klong =~ s/-/\\-/g;
    if($optlong{$k}) {
        # both short + long
        $l = "\\fI-".$optlong{$k}.", \\-\\-$klong\\fP$trail";
    }
    else {
        # only long
        $l = "\\fI\\-\\-$klong\\fP$trail";
    }
    return $l;
}


my $colwidth=78; # max number of columns

sub justline {
    my ($lvl, @line) = @_;
    my $w = -1;
    my $spaces = -1;
    my $width = $colwidth - ($lvl * 4);
    for(@line) {
        $w += length($_);
        $w++;
        $spaces++;
    }
    my $inject = $width - $w;
    my $ratio = 0; # stay at zero if no spaces at all
    if($spaces) {
        $ratio = $inject / $spaces;
    }
    my $spare = 0;
    print ' ' x ($lvl * 4);
    my $prev;
    for(@line) {
        while($spare >= 0.90) {
            print " ";
            $spare--;
        }
        printf "%s%s", $prev?" ":"", $_;
        $prev = 1;
        $spare += $ratio;
    }
    print "\n";
}

sub lastline {
    my ($lvl, @line) = @_;
    print ' ' x ($lvl * 4);
    my $prev = 0;
    for(@line) {
        printf "%s%s", $prev?" ":"", $_;
        $prev = 1;
    }
    print "\n";
}

sub outputpara {
    my ($lvl, $f) = @_;
    $f =~ s/\n/ /g;

    my $w = 0;
    my @words = split(/  */, $f);
    my $width = $colwidth - ($lvl * 4);

    my @line;
    for my $e (@words) {
        my $l = length($e);
        my $spaces = scalar(@line);
        if(($w + $l + $spaces) >= $width) {
            justline($lvl, @line);
            undef @line;
            $w = 0;
        }

        push @line, $e;
        $w += $l; # new width
    }
    if($w) {
        lastline($lvl, @line);
        print "\n";
    }
}

sub printdesc {
    my ($manpage, $baselvl, @desc) = @_;

    if($manpage) {
        for my $d (@desc) {
            print $d;
        }
    }
    else {
        my $p = -1;
        my $para;
        for my $l (@desc) {
            my $lvl;
            if($l !~ /^[\n\r]+/) {
                # get the indent level off the string
                $l =~ s/^\[([0-9q]*)\]//;
                $lvl = $1;
            }
            if(($p =~ /q/) && ($lvl !~ /q/)) {
                # the previous was quoted, this is not
                print "\n";
            }
            if($lvl != $p) {
                outputpara($baselvl + $p, $para);
                $para = "";
            }
            if($lvl =~ /q/) {
                # quoted, do not right-justify
                chomp $l;
                lastline($baselvl + $lvl + 1, $l);
            }
            else {
                $para .= $l;
            }

            $p = $lvl;
        }
        outputpara($baselvl + $p, $para);
    }
}

sub seealso {
    my($standalone, $data)=@_;
    if($standalone) {
        return sprintf
            ".SH \"SEE ALSO\"\n$data\n";
    }
    else {
        return "See also $data. ";
    }
}

sub overrides {
    my ($standalone, $data)=@_;
    if($standalone) {
        return ".SH \"OVERRIDES\"\n$data\n";
    }
    else {
        return $data;
    }
}

sub protocols {
    my ($manpage, $standalone, $data)=@_;
    if($standalone) {
        return ".SH \"PROTOCOLS\"\n$data\n";
    }
    else {
        return " ($data) " if($manpage);
        return "[1]($data) " if(!$manpage);
    }
}

sub too_old {
    my ($version)=@_;
    my $a = 999999;
    if($version =~ /^(\d+)\.(\d+)\.(\d+)/) {
        $a = $1 * 1000 + $2 * 10 + $3;
    }
    elsif($version =~ /^(\d+)\.(\d+)/) {
        $a = $1 * 1000 + $2 * 10;
    }
    if($a < 7500) {
        # we consider everything before 7.50.0 to be too old to mention
        # specific changes for
        return 1;
    }
    return 0;
}

sub added {
    my ($standalone, $data)=@_;
    if(too_old($data)) {
        # do not mention ancient additions
        return "";
    }
    if($standalone) {
        return ".SH \"ADDED\"\nAdded in curl version $data\n";
    }
    else {
        return "Added in $data. ";
    }
}

sub render {
    my ($manpage, $fh, $f, $line) = @_;
    my @desc;
    my $tablemode = 0;
    my $header = 0;
    # if $top is TRUE, it means a top-level page and not a command line option
    my $top = ($line == 1);
    my $quote;
    my $level;
    $start = 0;

    while(<$fh>) {
        my $d = $_;
        $line++;
        if($d =~ /^\.(SH|BR|IP|B)/) {
            print STDERR "$f:$line:1:ERROR: nroff instruction in input: \".$1\"\n";
            return 4;
        }
        if(/^ *<!--/) {
            # skip comments
            next;
        }
        if((!$start) && ($_ =~ /^[\r\n]*\z/)) {
            # skip leading blank lines
            next;
        }
        $start = 1;
        if(/^# (.*)/) {
            $header = 1;
            if($top != 1) {
                # ignored for command line options
                $blankline++;
                next;
            }
            push @desc, ".SH $1\n" if($manpage);
            push @desc, "[0]$1\n" if(!$manpage);
            next;
        }
        elsif(/^###/) {
            print STDERR "$f:$line:1:ERROR: ### header is not supported\n";
            exit 3;
        }
        elsif(/^## (.*)/) {
            my $word = $1;
            # if there are enclosing quotes, remove them first
            $word =~ s/[\"\'](.*)[\"\']\z/$1/;

            # remove backticks from headers
            $words =~ s/\`//g;

            # if there is a space, it needs quotes for man page
            if(($word =~ / /) && $manpage) {
                $word = "\"$word\"";
            }
            $level = 1;
            if($top == 1) {
                push @desc, ".IP $word\n" if($manpage);
                push @desc, "\n" if(!$manpage);
                push @desc, "[1]$word\n" if(!$manpage);
            }
            else {
                if(!$tablemode) {
                    push @desc, ".RS\n" if($manpage);
                    $tablemode = 1;
                }
                push @desc, ".IP $word\n" if($manpage);
                push @desc, "\n" if(!$manpage);
                push @desc, "[1]$word\n" if(!$manpage);
            }
            $header = 1;
            next;
        }
        elsif(/^##/) {
            if($top == 1) {
                print STDERR "$f:$line:1:ERROR: ## empty header top-level mode\n";
                exit 3;
            }
            if($tablemode) {
                # end of table
                push @desc, ".RE\n.IP\n";
                $tablemode = 0;
            }
            $header = 1;
            next;
        }
        elsif(/^\.(IP|RS|RE)/) {
            my ($cmd) = ($1);
            print STDERR "$f:$line:1:ERROR: $cmd detected, use ##-style\n";
            return 3;
        }
        elsif(/^[ \t]*\n/) {
            # count and ignore blank lines
            $blankline++;
            next;
        }
        elsif($d =~ /^    (.*)/) {
            my $word = $1;
            if(!$quote && $manpage) {
                push @desc, ".nf\n";
            }
            $quote = 1;
            $d = "$word\n";
        }
        elsif($quote && ($d !~ /^    (.*)/)) {
            # end of quote
            push @desc, ".fi\n" if($manpage);
            $quote = 0;
        }

        $d =~ s/`%DATE`/$date/g;
        $d =~ s/`%VERSION`/$version/g;
        $d =~ s/`%GLOBALS`/$globals/g;

        # convert backticks to double quotes
        $d =~ s/\`/\"/g;

        if($d =~ /\(Added in ([0-9.]+)\)/i) {
            my $ver = $1;
            if(too_old($ver)) {
                $d =~ s/ *\(Added in $ver\)//gi;
            }
        }

        if(!$quote) {
            if($d =~ /^(.*)  /) {
                printf STDERR "$f:$line:%d:ERROR: 2 spaces detected\n",
                    length($1);
                return 3;
            }
            elsif($d =~ /[^\\][\<\>]/) {
                print STDERR "$f:$line:1:WARN: un-escaped < or > used\n";
                return 3;
            }
        }
        # convert backslash-'<' or '> to just the second character
        $d =~ s/\\([><])/$1/g;
        # convert single backslash to double-backslash
        $d =~ s/\\/\\\\/g if($manpage);


        if($manpage) {
            if(!$quote && $d =~ /--/) {
                $d =~ s/--([a-z0-9.-]+)/manpageify($1)/ge;
            }

            # quote minuses in the output
            $d =~ s/([^\\])-/$1\\-/g;
            # replace single quotes
            $d =~ s/\'/\\(aq/g;
            # handle double quotes or periods first on the line
            $d =~ s/^([\.\"])/\\&$1/;
            # **bold**
            $d =~ s/\*\*(\S.*?)\*\*/\\fB$1\\fP/g;
            # *italics*
            $d =~ s/\*(\S.*?)\*/\\fI$1\\fP/g;
        }
        else {
            # **bold**
            $d =~ s/\*\*(\S.*?)\*\*/$1/g;
            # *italics*
            $d =~ s/\*(\S.*?)\*/$1/g;
        }
        # trim trailing spaces
        $d =~ s/[ \t]+\z//;
        push @desc, "\n" if($blankline && !$header);
        $blankline = 0;
        push @desc, $d if($manpage);
        my $qstr = $quote ? "q": "";
        push @desc, "[".(1 + $level)."$qstr]$d" if(!$manpage);
        $header = 0;

    }
    if($tablemode) {
        # end of table
        push @desc, ".RE\n.IP\n" if($manpage);
    }
    return @desc;
}

sub single {
    my ($manpage, $f, $standalone)=@_;
    my $fh;
    open($fh, "<:crlf", "$f") ||
        return 1;
    my $short;
    my $long;
    my $tags;
    my $added;
    my $protocols;
    my $arg;
    my $mutexed;
    my $requires;
    my $category;
    my @seealso;
    my $copyright;
    my $spdx;
    my @examples; # there can be more than one
    my $magic; # cmdline special option
    my $line;
    my $dline;
    my $multi;
    my $scope;
    my $experimental;
    my $start;
    my $list; # identifies the list, 1 example, 2 see-also
    while(<$fh>) {
        $line++;
        if(/^ *<!--/) {
            next;
        }
        if(!$start) {
            if(/^---/) {
                $start = 1;
            }
            next;
        }
        if(/^Short: *(.)/i) {
            $short=$1;
        }
        elsif(/^Long: *(.*)/i) {
            $long=$1;
        }
        elsif(/^Added: *(.*)/i) {
            $added=$1;
        }
        elsif(/^Tags: *(.*)/i) {
            $tags=$1;
        }
        elsif(/^Arg: *(.*)/i) {
            $arg=$1;
        }
        elsif(/^Magic: *(.*)/i) {
            $magic=$1;
        }
        elsif(/^Mutexed: *(.*)/i) {
            $mutexed=$1;
        }
        elsif(/^Protocols: *(.*)/i) {
            $protocols=$1;
        }
        elsif(/^See-also: +(.+)/i) {
            if($seealso) {
                print STDERR "ERROR: duplicated See-also in $f\n";
                return 1;
            }
            push @seealso, $1;
        }
        elsif(/^See-also:/i) {
            $list=2;
        }
        elsif(/^  *- (.*)/i && ($list == 2)) {
            push @seealso, $1;
        }
        elsif(/^Requires: *(.*)/i) {
            $requires=$1;
        }
        elsif(/^Category: *(.*)/i) {
            $category=$1;
        }
        elsif(/^Example: +(.+)/i) {
            push @examples, $1;
        }
        elsif(/^Example:/i) {
            # '1' is the example list
            $list = 1;
        }
        elsif(/^  *- (.*)/i && ($list == 1)) {
            push @examples, $1;
        }
        elsif(/^Multi: *(.*)/i) {
            $multi=$1;
        }
        elsif(/^Scope: *(.*)/i) {
            $scope=$1;
        }
        elsif(/^Experimental: yes/i) {
            $experimental=1;
        }
        elsif(/^C: (.*)/i) {
            $copyright=$1;
        }
        elsif(/^SPDX-License-Identifier: (.*)/i) {
            $spdx=$1;
        }
        elsif(/^Help: *(.*)/i) {
            ;
        }
        elsif(/^---/) {
            $start++;
            if(!$long) {
                print STDERR "ERROR: no 'Long:' in $f\n";
                return 1;
            }
            if(!$category) {
                print STDERR "ERROR: no 'Category:' in $f\n";
                return 2;
            }
            if(!$examples[0]) {
                print STDERR "$f:$line:1:ERROR: no 'Example:' present\n";
                return 2;
            }
            if(!$added) {
                print STDERR "$f:$line:1:ERROR: no 'Added:' version present\n";
                return 2;
            }
            if(!$seealso[0]) {
                print STDERR "$f:$line:1:ERROR: no 'See-also:' field present\n";
                return 2;
            }
            if(!$copyright) {
                print STDERR "$f:$line:1:ERROR: no 'C:' field present\n";
                return 2;
            }
            if(!$spdx) {
                print STDERR "$f:$line:1:ERROR: no 'SPDX-License-Identifier:' field present\n";
                return 2;
            }
            last;
        }
        else {
            chomp;
            print STDERR "$f:$line:1:WARN: unrecognized line in $f, ignoring:\n:'$_';"
        }
    }

    if($start < 2) {
        print STDERR "$f:1:1:ERROR: no proper meta-data header\n";
        return 2;
    }

    my @desc = render($manpage, $fh, $f, $line);
    close($fh);
    if($tablemode) {
        # end of table
        push @desc, ".RE\n.IP\n";
    }
    my $opt;

    if(defined($short) && $long) {
        $opt = "-$short, --$long";
    }
    elsif($short && !$long) {
        $opt = "-$short";
    }
    elsif($long && !$short) {
        $opt = "--$long";
    }

    if($arg) {
        $opt .= " $arg";
    }

    # quote "bare" minuses in opt
    $opt =~ s/-/\\-/g if($manpage);
    if($standalone) {
        print ".TH curl 1 \"30 Nov 2016\" \"curl 7.52.0\" \"curl manual\"\n";
        print ".SH OPTION\n";
        print "curl $opt\n";
    }
    elsif($manpage) {
        print ".IP \"$opt\"\n";
    }
    else {
        lastline(1, $opt);
    }
    my @leading;
    if($protocols) {
        push @leading, protocols($manpage, $standalone, $protocols);
    }

    if($standalone) {
        print ".SH DESCRIPTION\n";
    }

    if($experimental) {
        push @leading, "**WARNING**: this option is experimental. Do not use in production.\n\n";
    }

    my $pre = $manpage ? "\n": "[1]";

    if($scope) {
        if($scope eq "global") {
            push @desc, "\n" if(!$manpage);
            push @desc, "${pre}This option is global and does not need to be specified for each use of --next.\n";
        }
        else {
            print STDERR "$f:$line:1:ERROR: unrecognized scope: '$scope'\n";
            return 2;
        }
    }

    printdesc($manpage, 2, (@leading, @desc));
    undef @desc;

    my @extra;
    if($multi eq "single") {
        push @extra, "${pre}If --$long is provided several times, the last set ".
            "value is used.\n";
    }
    elsif($multi eq "append") {
        push @extra, "${pre}--$long can be used several times in a command line\n";
    }
    elsif($multi eq "boolean") {
        my $rev = "no-$long";
        # for options that start with "no-" the reverse is then without
        # the no- prefix
        if($long =~ /^no-/) {
            $rev = $long;
            $rev =~ s/^no-//;
        }
        my $dashes = $manpage ? "\\-\\-" : "--";
        push @extra,
            "${pre}Providing --$long multiple times has no extra effect.\n".
            "Disable it again with $dashes$rev.\n";
    }
    elsif($multi eq "mutex") {
        push @extra,
            "${pre}Providing --$long multiple times has no extra effect.\n";
    }
    elsif($multi eq "custom") {
        ; # left for the text to describe
    }
    else {
        print STDERR "$f:$line:1:ERROR: unrecognized Multi: '$multi'\n";
        return 2;
    }

    printdesc($manpage, 2, @extra);

    my @foot;

    my $mstr;
    my $and = 0;
    my $num = scalar(@seealso);
    if($num > 2) {
        # use commas up to this point
        $and = $num - 1;
    }
    my $i = 0;
    for my $k (@seealso) {
        if(!$helplong{$k}) {
            print STDERR "$f:$line:1:WARN: see-also a non-existing option: $k\n";
        }
        my $l = $manpage ? manpageify($k) : "--$k";
        my $sep = " and";
        if($and && ($i < $and)) {
            $sep = ",";
        }
        $mstr .= sprintf "%s$l", $mstr?"$sep ":"";
        $i++;
    }
    push @foot, seealso($standalone, $mstr);

    if($requires) {
        my $l = $manpage ? manpageify($long) : "--$long";
        push @foot, "$l requires that the underlying libcurl".
            " was built to support $requires. ";
    }
    if($mutexed) {
        my @m=split(/ /, $mutexed);
        my $mstr;
        for my $k (@m) {
            if(!$helplong{$k}) {
                print STDERR "WARN: $f mutexes a non-existing option: $k\n";
            }
            my $l = $manpage ? manpageify($k) : "--$k";
            $mstr .= sprintf "%s$l", $mstr?" and ":"";
        }
        push @foot, overrides($standalone,
                              "This option is mutually exclusive to $mstr. ");
    }
    if($examples[0]) {
        my $s ="";
        $s="s" if($examples[1]);
        if($manpage) {
            print "\nExample$s:\n";
            print ".nf\n";
            foreach my $e (@examples) {
                $e =~ s!\$URL!https://example.com!g;
                # convert single backslahes to doubles
                $e =~ s/\\/\\\\/g;
                print " curl $e\n";
            }
            print ".fi\n";
        }
        else {
            my @ex;
            push @ex, "[0q]Example$s:\n";
            foreach my $e (@examples) {
                $e =~ s!\$URL!https://example.com!g;
                push @ex, "[0q] curl $e\n";
            }
            printdesc($manpage, 2, @ex);
        }
    }
    if($added) {
        push @foot, added($standalone, $added);
    }
    if($foot[0]) {
        print "\n";
        my $f = join("", @foot);
        if($manpage) {
            $f =~ s/ +\z//; # remove trailing space
            print "$f\n";
        }
        else {
            printdesc($manpage, 2, "[1]$f");
        }
    }
    return 0;
}

sub getshortlong {
    my ($f)=@_;
    open(F, "<:crlf", "$f");
    my $short;
    my $long;
    my $help;
    my $arg;
    my $protocols;
    my $category;
    my $start = 0;
    while(<F>) {
        if(!$start) {
            if(/^---/) {
                $start = 1;
            }
            next;
        }
        if(/^Short: (.)/i) {
            $short=$1;
        }
        elsif(/^Long: (.*)/i) {
            $long=$1;
        }
        elsif(/^Help: (.*)/i) {
            $help=$1;
        }
        elsif(/^Arg: (.*)/i) {
            $arg=$1;
        }
        elsif(/^Protocols: (.*)/i) {
            $protocols=$1;
        }
        elsif(/^Category: (.*)/i) {
            $category=$1;
        }
        elsif(/^---/) {
            last;
        }
    }
    close(F);
    if($short) {
        $optshort{$short}=$long;
    }
    if($long) {
        $optlong{$long}=$short;
        $helplong{$long}=$help;
        $arglong{$long}=$arg;
        $protolong{$long}=$protocols;
        $catlong{$long}=$category;
    }
}

sub indexoptions {
    my (@files) = @_;
    foreach my $f (@files) {
        getshortlong($f);
    }
}

sub header {
    my ($manpage, $f)=@_;
    my $fh;
    open($fh, "<:crlf", "$f");
    my @d = render($manpage, $fh, $f, 1);
    close($fh);
    printdesc($manpage, 0, @d);
}

sub listhelp {
    print <<HEAD
/***************************************************************************
 *                                  _   _ ____  _
 *  Project                     ___| | | |  _ \\| |
 *                             / __| | | | |_) | |
 *                            | (__| |_| |  _ <| |___
 *                             \\___|\\___/|_| \\_\\_____|
 *
 * Copyright (C) Daniel Stenberg, <daniel\@haxx.se>, et al.
 *
 * This software is licensed as described in the file COPYING, which
 * you should have received as part of this distribution. The terms
 * are also available at https://curl.se/docs/copyright.html.
 *
 * You may opt to use, copy, modify, merge, publish, distribute and/or sell
 * copies of the Software, and permit persons to whom the Software is
 * furnished to do so, under the terms of the COPYING file.
 *
 * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
 * KIND, either express or implied.
 *
 * SPDX-License-Identifier: curl
 *
 ***************************************************************************/
#include "tool_setup.h"
#include "tool_help.h"

/*
 * DO NOT edit tool_listhelp.c manually.
 * This source file is generated with the following command in an autotools
 * build:
 *
 * "make listhelp"
 */

const struct helptxt helptext[] = {
HEAD
        ;
    foreach my $f (sort keys %helplong) {
        my $long = $f;
        my $short = $optlong{$long};
        my @categories = split ' ', $catlong{$long};
        my $bitmask = ' ';
        my $opt;

        if(defined($short) && $long) {
            $opt = "-$short, --$long";
        }
        elsif($long && !$short) {
            $opt = "    --$long";
        }
        for my $i (0 .. $#categories) {
            $bitmask .= 'CURLHELP_' . uc $categories[$i];
            # If not last element, append |
            if($i < $#categories) {
                $bitmask .= ' | ';
            }
        }
        $bitmask =~ s/(?=.{76}).{1,76}\|/$&\n  /g;
        my $arg = $arglong{$long};
        if($arg) {
            $opt .= " $arg";
        }
        my $desc = $helplong{$f};
        $desc =~ s/\"/\\\"/g; # escape double quotes

        my $line = sprintf "  {\"%s\",\n   \"%s\",\n  %s},\n", $opt, $desc, $bitmask;

        if(length($opt) > 78) {
            print STDERR "WARN: the --$long name is too long\n";
        }
        elsif(length($desc) > 78) {
            print STDERR "WARN: the --$long description is too long\n";
        }
        print $line;
    }
    print <<FOOT
  { NULL, NULL, CURLHELP_HIDDEN }
};
FOOT
        ;
}

sub listcats {
    my %allcats;
    foreach my $f (sort keys %helplong) {
        my @categories = split ' ', $catlong{$f};
        foreach (@categories) {
            $allcats{$_} = undef;
        }
    }
    my @categories;
    foreach my $key (keys %allcats) {
        push @categories, $key;
    }
    @categories = sort @categories;
    unshift @categories, 'hidden';
    for my $i (0..$#categories) {
        print '#define ' . 'CURLHELP_' . uc($categories[$i]) . ' ' . "1u << " . $i . "u\n";
    }
}

sub listglobals {
    my (@files) = @_;
    my @globalopts;

    # Find all global options and output them
    foreach my $f (sort @files) {
        open(F, "<:crlf", "$f") ||
            next;
        my $long;
        my $start = 0;
        while(<F>) {
            if(/^---/) {
                if(!$start) {
                    $start = 1;
                    next;
                }
                else {
                    last;
                }
            }
            if(/^Long: *(.*)/i) {
                $long=$1;
            }
            elsif(/^Scope: global/i) {
                push @globalopts, $long;
                last;
            }
        }
        close(F);
    }
    return $ret if($ret);
    for my $e (0 .. $#globalopts) {
        $globals .= sprintf "%s--%s",  $e?($globalopts[$e+1] ? ", " : " and "):"",
            $globalopts[$e],;
    }
}

sub noext {
    my $in = $_[0];
    $in =~ s/\.d//;
    return $in;
}

sub sortnames {
    return noext($a) cmp noext($b);
}

sub mainpage {
    my ($manpage, @files) = @_;
    # $manpage is 1 for nroff, 0 for ASCII
    my $ret;
    my $fh;
    open($fh, "<:crlf", "mainpage.idx") ||
        return 1;

    print <<HEADER
.\\" **************************************************************************
.\\" *                                  _   _ ____  _
.\\" *  Project                     ___| | | |  _ \\| |
.\\" *                             / __| | | | |_) | |
.\\" *                            | (__| |_| |  _ <| |___
.\\" *                             \\___|\\___/|_| \\_\\_____|
.\\" *
.\\" * Copyright (C) Daniel Stenberg, <daniel\@haxx.se>, et al.
.\\" *
.\\" * This software is licensed as described in the file COPYING, which
.\\" * you should have received as part of this distribution. The terms
.\\" * are also available at https://curl.se/docs/copyright.html.
.\\" *
.\\" * You may opt to use, copy, modify, merge, publish, distribute and/or sell
.\\" * copies of the Software, and permit persons to whom the Software is
.\\" * furnished to do so, under the terms of the COPYING file.
.\\" *
.\\" * This software is distributed on an "AS IS" basis, WITHOUT WARRANTY OF ANY
.\\" * KIND, either express or implied.
.\\" *
.\\" * SPDX-License-Identifier: curl
.\\" *
.\\" **************************************************************************
.\\"
.\\" DO NOT EDIT. Generated by the curl project gen.pl man page generator.
.\\"
.TH curl 1 "$date" "curl $version" "curl Manual"
HEADER
        if ($manpage);

    while(<$fh>) {
        my $f = $_;
        chomp $f;
        if($f =~ /^#/) {
            # standard comment
            next;
        }
        if(/^%options/) {
            # output docs for all options
            foreach my $f (sort sortnames @files) {
                $ret += single($manpage, $f, 0);
            }
        }
        else {
            # render the file
            header($manpage, $f);
        }
    }
    close($fh);
    exit $ret if($ret);
}

sub showonly {
    my ($f) = @_;
    if(single($f, 1)) {
        print STDERR "$f: failed\n";
    }
}

sub showprotocols {
    my %prots;
    foreach my $f (keys %optlong) {
        my @p = split(/ /, $protolong{$f});
        for my $p (@p) {
            $prots{$p}++;
        }
    }
    for(sort keys %prots) {
        printf "$_ (%d options)\n", $prots{$_};
    }
}

sub getargs {
    my ($f, @s) = @_;
    if($f eq "mainpage") {
        listglobals(@s);
        mainpage(1, @s);
        return;
    }
    elsif($f eq "ascii") {
        listglobals(@s);
        mainpage(0, @s);
        return;
    }
    elsif($f eq "listhelp") {
        listhelp();
        return;
    }
    elsif($f eq "single") {
        showonly($s[0]);
        return;
    }
    elsif($f eq "protos") {
        showprotocols();
        return;
    }
    elsif($f eq "listcats") {
        listcats();
        return;
    }

    print "Usage: gen.pl <mainpage/ascii/listhelp/single FILE/protos/listcats> [files]\n";
}

#------------------------------------------------------------------------

my $cmd = shift @ARGV;
my @files = @ARGV; # the rest are the files

# learn all existing options
indexoptions(@files);

getargs($cmd, @files);
