
use 5.014;
use strict;
use warnings;

package Sidef::Convert::Convert {

    require Sidef::Init;

    use overload

      q{""} => sub {
        my ($type) = ref($_[0]);

        if ($type eq 'Sidef::Types::Array::Array') {
            return $_[0];

            #return Sidef::Types::String::String->new('[' . join(', ', map {$_->{self}} @{$_[0]}) . ']'); #For Debug
        }

        return ${$_[0]};
      },

      q{eq} => sub {
        my $type_1 = ref($_[0]);
        my $type_2 = ref($_[1]);

        if ($type_1 eq 'Sidef::Types::Array::Array' or $type_2 eq 'Sidef::Types::Array::Array') {
            if ($type_1 eq 'Sidef::Types::Array::Array' and $type_2 eq 'Sidef::Types::Array::Array') {

                foreach my $item (@{$_[0]}) {
                    foreach my $comp_item (@{$_[1]}) {
                        $item eq $comp_item or return;
                    }
                }

                return 1;

            }
            else {
                return;
            }

        }
        ${$_[0]} eq ${$_[1]};

      };

    sub to_s {
        my ($self) = @_;

        if (ref $self eq 'Sidef::Types::Array::Array') {
            return Sidef::Types::String::String->new(join(' ', @{$self}));
        }

        Sidef::Types::String::String->new("$$self");
    }

    sub to_sd {
        my ($self) = @_;
        Sidef::Types::String::Double->new("$$self");
    }

    sub to_i {
        my ($self) = @_;
        Sidef::Types::Number::Integer->new($$self);
    }

    sub to_float {
        my ($self) = @_;
        Sidef::Types::Number::Float->new($$self);
    }

    sub to_file {
        my ($self) = @_;
        Sidef::Types::Glob::File->new($$self);
    }

    sub to_dir {
        my ($self) = @_;
        Sidef::Types::Glob::Dir->new($$self);
    }

    sub to_bool {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new($$self);
    }

    sub to_byte {
        my($self) = @_;
        Sidef::Types::Byte::Byte->new(ord $self);
    }

    sub to_bytes {
        my($self) = @_;
        Sidef::Types::Array::Array->new(map {Sidef::Types::Byte::Byte->new($_)} unpack "C*", $self);
    }

    sub to_array {
        my ($self) = @_;
        Sidef::Types::Array::Array->new($self);
    }
}

1;
