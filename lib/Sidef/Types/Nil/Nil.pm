
use 5.014;
use strict;
use warnings;

package Sidef::Types::Nil::Nil {

    use parent qw(Sidef Sidef::Convert::Convert);

    sub new {
        bless \(my $nil = 'nil'), __PACKAGE__;
    }

    sub dump {
        Sidef::Types::String::String->new('nil');
    }

}

1;
