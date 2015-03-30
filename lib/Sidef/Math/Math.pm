package Sidef::Math::Math {

    use 5.014;
    our @ISA = qw(Sidef);

    sub new {
        require Math::BigFloat;
        bless {}, __PACKAGE__;
    }

    sub e {
        my ($self, $places) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->bexp(1, defined($places) ? $places->get_value : ()));
    }

    sub exp {
        my ($self, $x, $places) = @_;
        Sidef::Types::Number::Number->new(
                                         Math::BigFloat->new($x->get_value)->bexp(defined($places) ? $places->get_value : ()));
    }

    sub pi {
        my ($self, $places) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->new(0)->bpi(defined($places) ? $places->get_value : ()));
    }

    *PI = \&pi;

    sub atan {
        my ($self, $x, $places) = @_;
        Sidef::Types::Number::Number->new(
                                        Math::BigFloat->new($x->get_value)->batan(defined($places) ? $places->get_value : ()));
    }

    sub atan2 {
        my ($self, $x, $y, $places) = @_;
        Sidef::Types::Number::Number->new(
                        Math::BigFloat->new($x->get_value)->batan2($y->get_value, defined($places) ? $places->get_value : ()));
    }

    sub cos {
        my ($self, $x, $places) = @_;
        Sidef::Types::Number::Number->new(
                                         Math::BigFloat->new($x->get_value)->bcos(defined($places) ? $places->get_value : ()));
    }

    sub sin {
        my ($self, $x, $places) = @_;
        Sidef::Types::Number::Number->new(
                                         Math::BigFloat->new($x->get_value)->bsin(defined($places) ? $places->get_value : ()));
    }

    sub asin {
        my ($self, $x, $places) = @_;
        $self->atan2(
                     $x,
                     $self->sqrt(
                           Sidef::Types::Number::Number->new(1)->subtract($self->pow($x, Sidef::Types::Number::Number->new(2)))
                     ),
                     $places
                    );
    }

    sub log {
        my ($self, $n, $base) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->new($n->get_value)->blog(defined($base) ? $base->get_value : ()));
    }

    sub log2 {
        my ($self, $n) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->new($n->get_value)->blog(2));
    }

    sub log10 {
        my ($self, $n) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->new($n->get_value)->blog(10));
    }

    sub npow2 {
        my ($self, $x) = @_;
        my $y = Math::BigFloat->new(2);
        Sidef::Types::Number::Number->new($y->blsft(Math::BigFloat->new($x->get_value)->blog($y)->as_int));
    }

    sub npow {
        my ($self, $x, $y) = @_;

        $x = Math::BigFloat->new($x->get_value);
        $y = Math::BigFloat->new($y->get_value);

        Sidef::Types::Number::Number->new($y->bpow($x->blog($y)->as_int->binc));
    }

    sub gcd {
        my ($self, @list) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat::bgcd(map { $_->get_value } @list));
    }

    sub abs {
        my ($self, $n) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->new($n->get_value)->babs);
    }

    sub lcm {
        my ($self, @list) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat::blcm(map { $_->get_value } @list));
    }

    sub inf {
        Sidef::Types::Number::Number->new(Math::BigFloat->binf);
    }

    sub precision {
        my ($self, $n) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->precision($n->get_value));
    }

    sub accuracy {
        my ($self, $n) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->accuracy($n->get_value));
    }

    sub ceil {
        my ($self, $n) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->new($n->get_value)->bceil);
    }

    sub floor {
        my ($self, $n) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->new($n->get_value)->bfloor);
    }

    sub sqrt {
        my ($self, $n) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->new($n->get_value)->bsqrt);
    }

    sub pow {
        my ($self, $n, $pow) = @_;
        Sidef::Types::Number::Number->new(Math::BigFloat->new($n->get_value)->bpow($pow->get_value));
    }

    sub sum {
        my ($self, @nums) = @_;

        require List::Util;
        Sidef::Types::Number::Number->new(List::Util::sum(map { $_->get_value } @nums));
    }

    sub max {
        my ($self, @nums) = @_;

        require List::Util;
        Sidef::Types::Number::Number->new(List::Util::max(map { $_->get_value } @nums));
    }

    sub min {
        my ($self, @nums) = @_;

        require List::Util;
        Sidef::Types::Number::Number->new(List::Util::min(map { $_->get_value } @nums));
    }

    sub avg {
        my ($self, @nums) = @_;
        Sidef::Types::Number::Number->new($self->sum(@nums)->get_value / @nums);
    }

    sub range_sum {
        my ($self, $from, $to, $step) = @_;

        $from = $from->get_value;
        $to   = $to->get_value;
        $step = defined($step) ? $step->get_value : 1;

        Sidef::Types::Number::Number->new(($from + $to) * (($to - $from) / $step + 1) / 2);
    }

    *rangeSum = \&range_sum;

    sub map {
        my ($self, $amount, $from, $to) = @_;

        $amount = $amount->get_value;
        $from   = $from->get_value;
        $to     = $to->get_value;

        my $step  = ($to - $from) / $amount;
        my $array = Sidef::Types::Array::Array->new();

        return $array if $step == 0;

        for (my $i = $from ; $i < $to ; $i += $step) {
            $array->push(Sidef::Types::Number::Number->new($i));
        }

        $array;
    }

    sub number_to_percentage {
        my ($self, $num, $from, $to) = @_;

        $num  = $num->get_value;
        $to   = $to->get_value;
        $from = $from->get_value;

        my $sum  = CORE::abs($to - $from);
        my $dist = CORE::abs($num - $to);

        Sidef::Types::Number::Number->new(($sum - $dist) / $sum * 100);
    }

    *num2percent = \&number_to_percentage;

    {
        no strict 'refs';
        foreach my $f (

            # (Plane, 2-dimensional) angles may be converted with the following functions.
            'rad2rad',
            'deg2deg',
            'grad2grad',
            'rad2deg',
            'deg2rad',
            'grad2deg',
            'deg2grad',
            'rad2grad',
            'grad2rad',

            # The tangent
            'tan',

            # The cofunctions of the sine, cosine,
            # and tangent (cosec/csc and cotan/cot are aliases)
            'csc',
            'cosec',
            'sec',
            'cot',
            'cotan',

            # The arcus (also known as the inverse) functions
            # of the sine, cosine, and tangent
            ##'asin',
            'acos',
            ##'atan',

            # The principal value of the arc tangent of y/x
            ##'atan2',

            #  The arcus cofunctions of the sine, cosine, and tangent (acosec/acsc and
            # acotan/acot are aliases).  Note that atan2(0, 0) is not well-defined.
            'acsc',
            'acosec',
            'asec',
            'acot',
            'acotan',

            # The hyperbolic sine, cosine, and tangent
            'sinh',
            'cosh',
            'tanh',

            # The cofunctions of the hyperbolic sine, cosine, and tangent
            # (cosech/csch and cotanh/coth are aliases)
            'csch',
            'cosech',
            'sech',
            'coth',
            'cotanh',

            # The area (also known as the inverse) functions of the hyperbolic sine,
            # cosine, and tangent
            'asinh',
            'acosh',
            'atanh',

            # The area cofunctions of the hyperbolic sine, cosine, and tangent
            # (acsch/acosech and acoth/acotanh are aliases)
            'acsch',
            'acosech',
            'asech',
            'acoth',
            'acotanh',

          ) {
            *{__PACKAGE__ . '::' . $f} = sub {
                my ($self, @rest) = @_;
                require Math::Trig;
                Sidef::Types::Number::Number->new((\&{'Math::Trig::' . $f})->(map { $_->get_value } @rest));
            };
        }
    }

};

1
