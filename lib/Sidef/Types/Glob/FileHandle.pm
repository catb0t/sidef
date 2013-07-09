
use 5.014;
use strict;
use warnings;

package Sidef::Types::Glob::FileHandle {

    sub new {
        my (undef, %opt) = @_;

        bless {
               fh   => $opt{fh},
               file => $opt{file},
              },
          __PACKAGE__;
    }

    sub get_value {
        $_[0]->{fh};
    }

    sub stdout {
        __PACKAGE__->new(fh   => \*STDOUT,
                         file => Sidef::Types::Nil::Nil->new,);
    }

    sub stderr {
        __PACKAGE__->new(fh   => \*STDERR,
                         file => Sidef::Types::Nil::Nil->new,);
    }

    sub stdin {
        __PACKAGE__->new(fh   => \*STDIN,
                         file => Sidef::Types::Nil::Nil->new,);
    }

    sub write {
        my ($self, $string) = @_;
        Sidef::Types::Bool::Bool->new(print {$self->{fh}} $string);
    }

    sub readline {
        my ($self) = @_;
        my $line = CORE::readline $self->{fh};
        defined($line) ? Sidef::Types::String::String->new($line) : Sidef::Types::Nil::Nil->new();
    }

    sub read_all {
        my ($self) = @_;
        Sidef::Types::Array::Array->new(map { Sidef::Types::String::String->new($_) } CORE::readline $self->{fh});
    }

    *getLines = \&read_all;

    sub eof {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(eof $self->{fh});
    }

    sub file {
        my ($self) = @_;
        $self->{file};
    }

    sub close {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new(close $self->{fh});
    }

};

1;
