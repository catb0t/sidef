use strict;
use warnings;

my $l = '^(?:AA:)(\w):(\w)';
my $r = '"!U!$1\.$2"';

(my $s = 'AA:B:C') =~ s{$l}"$r"ee;

print "want: !U!B.C\n";
print "got:  $s\n";
