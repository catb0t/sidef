
use 5.014;
use strict;
use warnings;

package Sidef::Types::Number::Number {

    use parent qw(Sidef::Convert::Convert);

    sub new {
        my ($class, $num) = @_;
        bless \$num, $class;
    }

    {
        no strict 'refs';

        *{__PACKAGE__ . '::' . '/'} = sub {
            my ($self, $num) = @_;
            __PACKAGE__->new($$self / $$num);
        };

        *{__PACKAGE__ . '::' . '/='} = sub {
            my ($self, $num) = @_;
            $$self /= $$num;
            $self;
        };

        *{__PACKAGE__ . '::' . '*'} = sub {
            my ($self, $num) = @_;
            __PACKAGE__->new($$self * $$num);
        };

        *{__PACKAGE__ . '::' . '*='} = sub {
            my ($self, $num) = @_;
            $$self *= $$num;
            $self;
        };

        *{__PACKAGE__ . '::' . '+'} = sub {
            my ($self, $num) = @_;
            __PACKAGE__->new($$self + $$num);
        };

        *{__PACKAGE__ . '::' . '+='} = sub {
            my ($self, $num) = @_;
            $$self += $$num;
            $self;
        };

        *{__PACKAGE__ . '::' . '-'} = sub {
            my ($self, $num) = @_;
            __PACKAGE__->new($$self - $$num);
        };

        *{__PACKAGE__ . '::' . '-='} = sub {
            my ($self, $num) = @_;
            $$self -= $$num;
            $self;
        };

        *{__PACKAGE__ . '::' . '%'} = sub {
            my ($self, $num) = @_;
            __PACKAGE__->new($$self % $$num);
        };

        *{__PACKAGE__ . '::' . '%='} = sub {
            my ($self, $num) = @_;
            $$self %= $$num;
            $self;
        };

        *{__PACKAGE__ . '::' . '**'} = sub {
            my ($self, $num) = @_;
            __PACKAGE__->new($$self**$$num);
        };

        *{__PACKAGE__ . '::' . '**='} = sub {
            my ($self, $num) = @_;
            $$self**= $$num;
            $self;
        };

        *{__PACKAGE__ . '::' . '++'} = sub {
            my ($self) = @_;
            ${$self}++;
            $self;
        };

        *{__PACKAGE__ . '::' . '<'} = sub {
            my ($self, $num) = @_;
            Sidef::Types::Bool::Bool->new($$self < $$num);
        };

        *{__PACKAGE__ . '::' . '>'} = sub {
            my ($self, $num) = @_;
            Sidef::Types::Bool::Bool->new($$self > $$num);
        };

        *{__PACKAGE__ . '::' . '<='} = sub {
            my ($self, $num) = @_;
            Sidef::Types::Bool::Bool->new($$self <= $$num);
        };

        *{__PACKAGE__ . '::' . '>='} = sub {
            my ($self, $num) = @_;
            Sidef::Types::Bool::Bool->new($$self >= $$num);
        };

        *{__PACKAGE__ . '::' . '=='} = sub {
            my ($self, $num) = @_;
            Sidef::Types::Bool::Bool->new($$self == $$num);
        };

        *{__PACKAGE__ . '::' . '!='} = sub {
            my ($self, $num) = @_;
            Sidef::Types::Bool::Bool->new($$self != $$num);
        };

        *{__PACKAGE__ . '::' . '..'} = sub {
            my ($self, $num) = @_;
            Sidef::Types::Array::Array->new(map { __PACKAGE__->new($_) } $$self .. $$num);
        };
    }

    sub sqrt {
        my ($self) = @_;
        Sidef::Types::Number::Float->new(CORE::sqrt $$self);
    }

    sub abs {
        my ($self) = @_;
        __PACKAGE__->new(CORE::abs $$self);
    }

    sub int {
        my ($self) = @_;
        Sidef::Types::Number::Integer->new($$self);
    }

    sub log {
        my ($self) = @_;
        Sidef::Types::Number::Float->new(CORE::log $$self);
    }

    sub log10 {
        my ($self) = @_;
        Sidef::Types::Number::Float->new(CORE::log($$self) / CORE::log(10));
    }

    sub log2 {
        my ($self) = @_;
        Sidef::Types::Number::Float->new(CORE::log($$self) / CORE::log(2));
    }

    sub chr {
        my ($self) = @_;
        Sidef::Types::Char::Char->new(CORE::chr $$self);
    }

    sub next_power_of_two {
        my ($self) = @_;
        Sidef::Types::Number::Integer->new(2 << CORE::log($$self) / CORE::log(2));
    }
};

1;
