package Sidef::Types::Number::Number {

    use 5.014;
    use strict;
    use warnings;

    require Math::BigFloat;

    our @ISA = qw(
      Sidef
      Sidef::Convert::Convert
      );

    sub new {
        my (undef, $num) = @_;

        ref($num) eq 'Math::BigFloat'
          ? (bless \$num, __PACKAGE__)
          : (bless \Math::BigFloat->new($num), __PACKAGE__);
    }

    sub newInt {
        my (undef, $num) = @_;

            ref($num) eq 'Math::BigInt' ? (bless \$num, __PACKAGE__)
          : ref($num) eq 'Math::BigFloat' || ref($num) eq __PACKAGE__ ? (bless \Math::BigInt->new($num->as_int))
          :   (bless \Math::BigInt->new(${__PACKAGE__->new($num)}->as_int), __PACKAGE__);
    }

    *new_int = \&newInt;

    sub get_value { ${$_[0]}->numify }

    {
        no strict 'refs';

        *{__PACKAGE__ . '::' . '/'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            $self->new($$self / $$num);
        };

        *{__PACKAGE__ . '::' . '*'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            $self->new($$self * $$num);
        };

        *{__PACKAGE__ . '::' . '+'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            $self->new($$self + $$num);
        };

        *{__PACKAGE__ . '::' . '-'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            $self->new($$self - $$num);
        };

        *{__PACKAGE__ . '::' . '%'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            $self->new($$self % $$num);
        };

        *{__PACKAGE__ . '::' . '**'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            $self->new($$self**$$num);
        };

        *{__PACKAGE__ . '::' . '++'} = sub {
            my ($self) = @_;
            $self->new($$self->copy->binc);
        };

        *{__PACKAGE__ . '::' . '--'} = sub {
            my ($self) = @_;
            $self->new($$self->copy->bdec);
        };

        *{__PACKAGE__ . '::' . '<'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            Sidef::Types::Bool::Bool->new($$self < $$num);
        };

        *{__PACKAGE__ . '::' . '>'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            Sidef::Types::Bool::Bool->new($$self > $$num);
        };

        *{__PACKAGE__ . '::' . '>>'} = sub {
            my ($self, $num, $base) = @_;
            $self->_is_number($num) || return;
            $self->new($$self->copy->brsft($num, defined($base) ? $self->_is_number($base) ? $$base : return : ()));
        };

        *{__PACKAGE__ . '::' . '<<'} = sub {
            my ($self, $num, $base) = @_;
            $self->_is_number($num) || return;
            $self->new($$self->copy->blsft($num, defined($base) ? $self->_is_number($base) ? $$base : return : ()));
        };

        *{__PACKAGE__ . '::' . '&'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            $self->new($$self->as_int->band($$num->as_int));
        };

        *{__PACKAGE__ . '::' . '|'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            $self->new($$self->as_int->bior($$num->as_int));
        };

        *{__PACKAGE__ . '::' . '^'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            $self->new($$self->as_int->bxor($$num->as_int));
        };

        *{__PACKAGE__ . '::' . '<=>'} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            Sidef::Types::Number::Number->new($$self->bcmp($$num));
        };

        *{__PACKAGE__ . '::' . '<='} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            Sidef::Types::Bool::Bool->new($$self <= $$num);
        };

        *{__PACKAGE__ . '::' . '>='} = sub {
            my ($self, $num) = @_;
            $self->_is_number($num) || return;
            Sidef::Types::Bool::Bool->new($$self >= $$num);
        };

        *{__PACKAGE__ . '::' . '=='} = sub {
            my ($self, $num) = @_;
            ref($self) ne ref($num) and return Sidef::Types::Bool::Bool->false;
            Sidef::Types::Bool::Bool->new($$self == $$num);
        };

        *{__PACKAGE__ . '::' . '!='} = sub {
            my ($self, $num) = @_;
            ref($self) ne ref($num) and return Sidef::Types::Bool::Bool->true;
            Sidef::Types::Bool::Bool->new($$self != $$num);
        };

        *{__PACKAGE__ . '::' . '..'} = \&to;

        *{__PACKAGE__ . '::' . '!'} = \&factorial;
    }

    sub factorial {
        my ($self) = @_;
        $self->new($$self->copy->bfac);
    }

    *fac = \&factorial;

    sub to {
        my ($self, $num) = @_;
        $self->_is_number($num) || return;
        Sidef::Types::Array::Array->new(map { $self->new($_) } $$self->numify .. $$num->numify);
    }

    *upto = \&to;
    *upTo = \&to;

    sub downto {
        my ($self, $num) = @_;
        $self->_is_number($num) || return;
        Sidef::Types::Array::Array->new(map { $self->new($_) } reverse($$num->numify .. $$self->numify));
    }

    *downTo = \&downto;

    sub sqrt {
        my ($self) = @_;
        $self->new(sqrt $$self);
    }

    sub root {
        my ($self, $n) = @_;
        $self->_is_number($n) || return;
        $self->new($$self->broot($n));
    }

    sub abs {
        my ($self) = @_;
        $self->new(CORE::abs $$self);
    }

    sub hex {
        my ($self) = @_;
        $self->new(CORE::hex $$self);
    }

    sub exp {
        my ($self) = @_;
        $self->new(CORE::exp $$self);
    }

    sub int {
        my ($self) = @_;
        $self->new($$self->as_int);
    }

    *as_int = \&int;

    sub cos {
        my ($self) = @_;
        $self->new(CORE::cos $$self);
    }

    sub sin {
        my ($self) = @_;
        $self->new(CORE::sin $$self);
    }

    sub log {
        my ($self, $base) = @_;
        $self->new($$self->copy->blog(defined($base) ? $self->_is_number($base) ? ($$base) : return : ()));
    }

    sub log10 {
        my ($self) = @_;
        $self->new($self->new($$self->copy->blog(10)));
    }

    sub log2 {
        my ($self) = @_;
        $self->new($self->new($$self->copy->blog(2)));
    }

    sub inf {
        my ($self) = @_;
        $self->new('inf');
    }

    sub neg {
        my ($self) = @_;
        $self->new($$self->copy->bneg);
    }

    *negate = \&neg;

    sub not {
        my ($self) = @_;
        $self->new($$self->copy->bnot);
    }

    sub sign {
        my ($self) = @_;
        Sidef::Types::String::String->new($$self->sign);
    }

    sub nan {
        my ($self) = @_;
        $self->new(Math::BigFloat->bnan);
    }

    *NaN = \&nan;

    sub chr {
        my ($self) = @_;
        Sidef::Types::Char::Char->new(CORE::chr $self->get_value);
    }

    sub next_power_of_two {
        my ($self) = @_;
        $self->new(2 << CORE::int(CORE::log($$self) / CORE::log(2)));
    }

    *nextPowerOfTwo = \&next_power_of_two;

    sub is_nan {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new($$self->is_nan);
    }

    *isNaN  = \&is_nan;
    *is_NaN = \&is_nan;

    sub is_positive {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new($$self > 0);
    }

    *isPositive = \&is_positive;
    *isPos      = \&is_positive;
    *is_pos     = \&is_positive;

    sub is_negative {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new($$self < 0);
    }

    *isNegative = \&is_negative;
    *isNeg      = \&is_negative;
    *is_neg     = \&is_negative;

    sub is_even {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new($$self % 2 == 0);
    }

    *isEven = \&is_even;

    sub is_odd {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new($$self % 2 != 0);
    }

    *isOdd = \&is_odd;

    sub is_integer {
        my ($self) = @_;
        Sidef::Types::Bool::Bool->new($$self == $$self->as_int);
    }

    *isInt     = \&is_integer;
    *is_int    = \&is_integer;
    *isInteger = \&is_integer;

    sub rand {
        my ($self, $max) = @_;

        my $min = $$self;
        $max = ref($max) ? $$max : do { $min = 0; $$self };

        $self->new($min + rand($max - $min));
    }

    sub ceil {
        my ($self) = @_;
        $self->new($$self->bceil);
    }

    sub floor {
        my ($self) = @_;
        $self->new($$self->bfloor);
    }

    sub round {
        my ($self, $places) = @_;
        $self->new($$self->bround(defined($places) ? ($self->_is_number($places)) ? ($$places) : (return) : ()));
    }

    sub roundf {
        my ($self, $places) = @_;
        $self->new($$self->bfround(defined($places) ? ($self->_is_number($places)) ? ($$places) : (return) : ()));
    }

    *fround = \&roundf;
    *fRound = \&roundf;

    sub range {
        my ($self) = @_;
        $$self >= 0 ? $self->new(0)->to($self) : $self->to($self->new(0));
    }

    sub length {
        my ($self) = @_;
        $self->new($$self->length);
    }

    *len = \&length;

    sub commify {
        my ($self) = @_;

        my $n = $$self->bstr;
        my $x = $n;

        my $neg = $n =~ s{^-}{};
        $n =~ /\.|$/;

        if ($-[0] > 3) {

            my $l = $-[0] - 3;
            my $i = ($l - 1) % 3 + 1;

            $x = substr($n, 0, $i) . ',';

            while ($i < $l) {
                $x .= substr($n, $i, 3) . ',';
                $i += 3;
            }

            $x .= substr($n, $i);
        }

        Sidef::Types::String::String->new(($neg ? '-' : '') . $x);
    }

    sub dump {
        my ($self) = @_;
        Sidef::Types::String::String->new($$self);
    }
}
