#!/usr/bin/perl

# Author: Daniel "Trizen" Șuteu
# License: GPLv3
# Date: 13 March 2015
# Website: http://github.com/trizen

#
## Test the Sidef deparser for consistency.
#

## Algorithm:
# - parse the code
# - deparse the code as D1
# - deparse the deparsed code as D2
# - if D1 != D2: throw an error

use utf8;
use 5.014;
use strict;
use autodie;
use warnings;

no warnings 'once';
use lib qw(../lib);

use Sidef;

use File::Find qw(find);
use File::Basename qw(basename);
use File::Spec::Functions qw(catdir updir rel2abs);

sub parse_deparse {
    my ($code, $name) = @_;

    my $sidef = Sidef->new(name => $name);

    my $ast = $sidef->parse_code($code);
    my $deparser = Sidef::Deparse::Sidef->new(namespaces => $sidef->{namespaces});

    my @statements = $deparser->deparse_script($ast);
    my $deparsed   = $deparser->{before} . join($deparser->{between}, @statements) . $deparser->{after};

    return ($deparsed, \@statements);
}

my %ignore = (
              'barnsley_fern.sf'     => 1,
             );

my $dir = catdir(updir, 'scripts');

find {
      wanted => sub { /\.s[fm]\z/ && (-f $_) && test_file($_) },
      no_chdir => 1,
     } => $dir;

sub test_file {
    my ($file) = @_;

    my $basename = basename($file);
    return if exists $ignore{$basename};

    {
        local $| = 1;
        printf("** Processing: %s\r", $file);
    }

    open my $fh, '<:utf8', $file;
    my $content = do { local $/; <$fh> };
    close $fh;

    my ($deparse_1, $statements_1) = parse_deparse($content,   $file);
    my ($deparse_2, $statements_2) = parse_deparse($deparse_1, $file);

    if ($deparse_1 ne $deparse_2) {

        require Algorithm::Diff;
        my $diff = Algorithm::Diff::diff($statements_1, $statements_2);

        require Data::Dump;
        Data::Dump::pp($diff);
        die "[!] Error detected on file: $file\n";
    }
}
