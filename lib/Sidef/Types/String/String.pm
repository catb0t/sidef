
use 5.014;
use strict;
use warnings;

package Sidef::Types::String::String {

    use parent qw(Sidef::Convert::Convert);

    sub new {
        my ($class, $str) = @_;
        bless \$str, $class;
    }

    sub uc {
        my ($self) = @_;
        __PACKAGE__->new(CORE::uc $$self);
    }

    sub ucfirst {
        my ($self) = @_;
        __PACKAGE__->new(CORE::ucfirst $$self);
    }

    sub lc {
        my ($self) = @_;
        __PACKAGE__->new(CORE::lc $$self);
    }

    sub lcfirst {
        my ($self) = @_;
        __PACKAGE__->new(CORE::lcfirst $$self);
    }

    sub chop {
        my ($self) = @_;
        __PACKAGE__->new(CORE::chop $$self);
    }

    sub chomp {
        my ($self) = @_;

        CORE::chomp($$self) || return $self;
        __PACKAGE__->new($$self);
    }

    sub substr {
        my ($self, $offs, $len, $repl) = @_;

        my @str = CORE::split(//, $$self);
        my $str_len = $#str;

        $offs = 1 + $str_len + $$offs if $$offs < 0;
        $len = defined $len ? $len < 0 ? $str_len + $len : $offs + $len - 1 : $str_len;

        if (defined $repl) {
            $self = __PACKAGE__->new(CORE::join '', @str[0 .. $offs - 1], $repl, @str[$len + 1 .. $str_len]);
        }

        __PACKAGE__->new(CORE::join '', @str[$offs .. $len]);
    }

    #
    # "str1"->join('delim', "str2", "str3", ...);
    #
    sub join {
        my ($self, $delim, @rest) = @_;
        __PACKAGE__->new(CORE::join($$delim, $$self, map { $$_ } @rest));
    }

    sub reverse {
        my ($self) = @_;
        __PACKAGE__->new(scalar CORE::reverse $$self);
    }

    sub say {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(CORE::say $$self);
    }

    sub print {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(CORE::print $$self);
    }

    sub stat_file {
        my ($self) = @_;
        Sidef::Types::Glob::File->new($$self);
    }

    sub stat_dir {
        my ($self) = @_;
        Sidef::Types::Glob::Dir->new($$self);
    }
}

1;
