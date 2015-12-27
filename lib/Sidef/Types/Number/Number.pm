package Sidef::Types::Number::Number {

    use utf8;
    use 5.014;

    require Math::GMPq;
    require Math::GMPz;
    require Math::GMPf;
    require Math::MPFR;

    use parent qw(
      Sidef::Object::Object
      Sidef::Convert::Convert
      );

    our $ROUND = Math::MPFR::MPFR_RNDN();
    our $PREC  = 128;

    our $GET_PERL_VALUE = 0;

    our $ONE  = bless(\Math::GMPq->new(1),  __PACKAGE__);
    our $ZERO = bless(\Math::GMPq->new(0),  __PACKAGE__);
    our $MONE = bless(\Math::GMPq->new(-1), __PACKAGE__);

    use overload
      q{bool} => sub { Math::GMPq::Rmpq_sgn(${$_[0]}) != 0 },
      q{0+}   => sub { Math::GMPq::Rmpq_get_d(${$_[0]}) },
      q{""}   => \&get_value;

    sub _load_bigint {
        state $bigint = do {
            require Math::BigInt;
            Math::BigInt->import(try => 'GMP');
        };
    }

    sub _load_bigrat {
        state $bigrat = do {
            require Math::BigRat;
            Math::BigRat->import('try' => 'GMP');
        };
    }

    sub _new {
        (ref($_[0]) eq 'Sidef::Types::Number::Inf' or ref($_[0]) eq 'Sidef::Types::Number::Ninf')
          ? $_[0]
          : bless(\$_[0], __PACKAGE__);
    }

    sub _new_int {
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_si($r, $_[0], 1);
        bless \$r, __PACKAGE__;
    }

    sub _new_uint {
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_ui($r, $_[0], 1);
        bless \$r, __PACKAGE__;
    }

    sub new {
        my (undef, $num, $base) = @_;

        $base = defined($base) ? ref($base) ? $base->get_value : $base : 10;

        ref($num) eq __PACKAGE__ ? $num : do {

            $num = $num->get_value
              if (index(ref($num), 'Sidef::') == 0);

            ref($num) eq 'Math::GMPq'
              ? bless(\$num, __PACKAGE__)
              : bless(\Math::GMPq->new($base == 10 ? _str2rat($num // 0) : ($num // 0), $base), __PACKAGE__);
          }
    }

    *call = \&new;

    sub _valid {
        (
         ref($_) eq __PACKAGE__
           or die "[ERROR] Invalid argument `$_` of type "
           . Sidef::normalize_type(ref($_)) . " in "
           . Sidef::normalize_method((caller(1))[3])
           . "(). Expected an argument of type Number!\n"
        )
          for @_;
    }

    sub _as_float {
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_q($r, ${$_[0]}, $ROUND);
        $r;
    }

    sub _as_int {
        my $i = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($i, ${$_[0]});
        $i;
    }

    sub _mpfr2rat {

        #~ my ($mantissa, $exponent) = Math::MPFR::Rmpfr_deref2($_[0], 10, 0, $ROUND);
        #~ my $r = Math::GMPq::Rmpq_init();
        #~ Math::GMPq::Rmpq_set_str($r, "$mantissa/1" . ('0' x (length($mantissa) - $exponent)), 10);
        #~ Math::GMPq::Rmpq_canonicalize($r);
        #~ $r

        if (Math::MPFR::Rmpfr_inf_p($_[0])) {
            return (Math::MPFR::Rmpfr_sgn($_[0]) > 0 ? inf() : ninf());
        }

        if (Math::MPFR::Rmpfr_nan_p($_[0])) {
            return nan();
        }

        if (Math::MPFR::Rmpfr_integer_p($_[0])) {
            my $z = Math::GMPz::Rmpz_init_nobless();
            Math::MPFR::Rmpfr_get_z($z, $_[0], $ROUND);

            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_z($r, $z);
            Math::GMPz::Rmpz_clear($z);
            $r;
        }
        else {
            my $f = Math::GMPf::Rmpf_init2_nobless($PREC);
            Math::MPFR::Rmpfr_get_f($f, $_[0], $ROUND);

            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_f($r, $f);
            Math::GMPf::Rmpf_clear($f);
            $r;
        }

        #Math::GMPq->new("$mantissa/1" . ('0' x (length($mantissa) - $exponent)));
        #my $str = Math::MPFR::Rmpfr_get_str($_[0], 10, 0, $ROUND);
        #Math::GMPq->new(_str2rat($str));
    }

    sub _mpz2rat {
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_z($r, $_[0]);
        $r;
    }

    sub _str2rat {
        my ($str) = @_;

        my $sign = substr($str, 0, 1);
        if ($sign eq '-') {
            substr($str, 0, 1, '');
            $sign = '-';
        }
        else {
            substr($str, 0, 1, '') if ($sign eq '+');
            $sign = '';
        }

        if ((my $i = index($str, 'e')) != -1) {

            my $exp = substr($str, $i + 1);
            my ($before, $after) = split(/\./, substr($str, 0, $i));
            my $numerator = $before . $after;

            my $denominator = 1;
            if ($exp < 1) {
                $denominator .= '0' x (abs($exp) + length($after));
            }
            else {
                my $diff = ($exp - length($after));
                if ($diff >= 0) {
                    $numerator .= '0' x $diff;
                }
                else {
                    my $s = $before . $after;
                    substr($s, $exp + length($before), 0, '.');
                    return _str2rat("$sign$s");
                }
            }

            "$sign$numerator/$denominator";
        }
        elsif ((my $i = index($str, '.')) != -1) {
            my ($before, $after) = (substr($str, 0, $i), substr($str, $i + 1));
            if ($after =~ tr/0// == length($after)) {
                return "$sign$before";
            }
            $sign . ("$before$after/1" =~ s/^0+//r) . ('0' x length($after));
        }
        else {
            $sign . $str;
        }
    }

    sub get_value {
        $GET_PERL_VALUE ? Math::GMPq::Rmpq_get_d(${$_[0]}) : do {

            my $v = Math::GMPq::Rmpq_get_str(${$_[0]}, 10);

            if (index($v, '/') != -1) {
                state $bigrat = _load_bigrat();
                my $br = Math::BigRat->new($v);
                $br->as_float(CORE::int($PREC / 3.321923))->bstr =~ s/0+$//r;
            }
            else {
                $v;
            }
          }
    }

    sub _get_frac {
        Math::GMPq::Rmpq_get_str(${$_[0]}, 10);
    }

    #
    ## Constants
    #

    sub pi {
        my $pi = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_const_pi($pi, $ROUND);
        _new(_mpfr2rat($pi));
    }

    sub e {
        state $one_f = (Math::MPFR::Rmpfr_init_set_ui(1, $ROUND))[0];
        my $e = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_exp($e, $one_f, $ROUND);
        _new(_mpfr2rat($e));
    }

    sub phi {
        state $one_f  = (Math::MPFR::Rmpfr_init_set_ui(1, $ROUND))[0];
        state $two_f  = (Math::MPFR::Rmpfr_init_set_ui(2, $ROUND))[0];
        state $five_f = (Math::MPFR::Rmpfr_init_set_ui(5, $ROUND))[0];

        my $phi = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_sqrt($phi, $five_f, $ROUND);
        Math::MPFR::Rmpfr_add($phi, $phi, $one_f, $ROUND);
        Math::MPFR::Rmpfr_div($phi, $phi, $two_f, $ROUND);

        _new(_mpfr2rat($phi));
    }

    sub nan  { state $x = Sidef::Types::Number::Nan->new }
    sub inf  { state $x = Sidef::Types::Number::Inf->new }
    sub ninf { state $x = Sidef::Types::Number::Ninf->new }

    #
    ## Rational operations
    #

    sub add {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return $y->new($x)->add($y);
        }

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $y;
        }

        _valid($y);

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_add($r, $$x, $$y);
        _new($r);
    }

    sub sub {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return $y->new($x)->sub($y);
        }

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $y->neg;
        }

        _valid($y);

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_sub($r, $$x, $$y);
        _new($r);
    }

    sub div {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return $y->new($x)->div($y);
        }

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $ZERO;
        }

        _valid($y);

        if (Math::GMPq::Rmpq_sgn($$y) == 0) {
            my $sign = Math::GMPq::Rmpq_sgn($$x);
            return ($sign == 0 ? nan() : $sign > 0 ? inf() : ninf());
        }

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_div($r, $$x, $$y);
        _new($r);
    }

    *rdiv = \&div;

    sub mul {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return $y->new($x)->mul($y);
        }

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (Math::GMPq::Rmpq_sgn($$x) < 0 ? $y->neg : $y);
        }

        _valid($y);

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_mul($r, $$x, $$y);
        _new($r);
    }

    sub neg {
        my ($x) = @_;
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_neg($r, $$x);
        _new($r);
    }

    *negative = \&neg;

    sub abs {
        my ($x) = @_;
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_abs($r, $$x);
        _new($r);
    }

    *pos      = \&abs;
    *positive = \&abs;

    sub inv {
        my ($x) = @_;
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_inv($r, $$x);
        _new($r);
    }

    sub sqrt {
        my ($x) = @_;

        # Return a complex number for x < 0
        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->sqrt;
        }

        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_sqrt($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub cbrt {
        my ($x) = @_;

        # Return a complex number for x < 0
        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->cbrt;
        }

        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_cbrt($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub root {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $ONE;
        }

        _valid($y);
        return $x->pow($ONE->div($y));
    }

    sub sqr {
        my ($x) = @_;
        $x->mul($x);
    }

    sub pow {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return $y->new($x)->pow($y);
        }

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return $y;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $ZERO;
        }

        _valid($y);

        if (Math::GMPq::Rmpq_sgn($$y) >= 0 and _is_int($$x) and _is_int($$y)) {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $$x);
            Math::GMPz::Rmpz_pow_ui($z, $z, Math::GMPq::Rmpq_get_d($$y));
            return _new(_mpz2rat($z));
        }

        if (Math::GMPq::Rmpq_sgn($$x) < 0 and not _is_int($$y)) {
            return Sidef::Types::Number::Complex->new($x)->pow($y);
        }

        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_pow($r, _as_float($x), _as_float($y), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub fmod {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_fmod($r, _as_float($x), _as_float($y), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub log {
        my ($x, $y) = @_;

        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->log($y);
        }

        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_log($r, _as_float($x), $ROUND);

        if (defined $y) {

            if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
                return $ZERO;
            }

            _valid($y);
            my $baseln = Math::MPFR::Rmpfr_init2($PREC);
            Math::MPFR::Rmpfr_log($baseln, _as_float($y), $ROUND);
            Math::MPFR::Rmpfr_div($r, $r, $baseln, $ROUND);
        }

        _new(_mpfr2rat($r));
    }

    sub ln {
        my ($x) = @_;

        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->ln;
        }

        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_log($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub log2 {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_log2($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub log10 {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_log10($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub exp {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_exp($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub exp2 {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_exp2($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub exp10 {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_exp10($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    #
    ## Trigonometric functions
    #

    sub sin {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_sin($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub asin {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_asin($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub sinh {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_sinh($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub asinh {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_asinh($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub cos {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_cos($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub acos {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_acos($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub cosh {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_cosh($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub acosh {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_acosh($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub tan {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_tan($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub atan {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_atan($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub tanh {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_tanh($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub atanh {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_atanh($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub sec {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_sec($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub sech {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_sech($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub csc {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_csc($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub csch {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_csch($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub cot {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_cot($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub coth {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_coth($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    #
    ## Special functions
    #

    sub agm {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_agm($r, _as_float($x), _as_float($y), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub hypot {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_hypot($r, _as_float($x), _as_float($y), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub gamma {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_gamma($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub lgamma {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_lgamma($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub digamma {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_digamma($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub zeta {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_zeta($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub erf {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_erf($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub erfc {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_erfc($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub eint {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_eint($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    sub li2 {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_li2($r, _as_float($x), $ROUND);
        _new(_mpfr2rat($r));
    }

    #
    ## Comparison and testing operations
    #

    sub eq {
        my ($x, $y) = @_;
        _valid($y);
        Sidef::Types::Bool::Bool->new(Math::GMPq::Rmpq_equal($$x, $$y));
    }

    sub ne {
        my ($x, $y) = @_;
        _valid($y);
        Sidef::Types::Bool::Bool->new(!Math::GMPq::Rmpq_equal($$x, $$y));
    }

    sub cmp {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return $MONE;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $ONE;
        }

        _valid($y);
        my $cmp = Math::GMPq::Rmpq_cmp($$x, $$y);
        $cmp == 0 ? $ZERO : $cmp < 0 ? $MONE : $ONE;
    }

    sub acmp {
        my ($x, $y) = @_;

        _valid($y);

        my $xn = $$x;
        my $yn = $$y;

        my $a1 = Math::GMPq::Rmpq_sgn($xn) < 0
          ? do {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_abs($r, $xn);
            $r;
          }
          : $xn;

        my $a2 = Math::GMPq::Rmpq_sgn($yn) < 0
          ? do {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_abs($r, $yn);
            $r;
          }
          : $yn;

        my $cmp = Math::GMPq::Rmpq_cmp($a1, $a2);
        $cmp == 0 ? $ZERO : $cmp < 0 ? $MONE : $ONE;
    }

    sub gt {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return state $x = Sidef::Types::Bool::Bool->false;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return state $x = Sidef::Types::Bool::Bool->true;
        }

        _valid($y);

        Sidef::Types::Bool::Bool->new(Math::GMPq::Rmpq_cmp($$x, $$y) > 0);
    }

    sub ge {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return state $x = Sidef::Types::Bool::Bool->false;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return state $x = Sidef::Types::Bool::Bool->true;
        }

        _valid($y);

        Sidef::Types::Bool::Bool->new(Math::GMPq::Rmpq_cmp($$x, $$y) >= 0);
    }

    sub lt {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return state $x = Sidef::Types::Bool::Bool->true;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return state $x = Sidef::Types::Bool::Bool->false;
        }

        _valid($y);

        Sidef::Types::Bool::Bool->new(Math::GMPq::Rmpq_cmp($$x, $$y) < 0);
    }

    sub le {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return state $x = Sidef::Types::Bool::Bool->true;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return state $x = Sidef::Types::Bool::Bool->false;
        }

        _valid($y);

        Sidef::Types::Bool::Bool->new(Math::GMPq::Rmpq_cmp($$x, $$y) <= 0);
    }

    sub is_zero {
        my ($x) = @_;
        Sidef::Types::Bool::Bool->new(Math::GMPq::Rmpq_sgn($$x) == 0);
    }

    sub is_one {
        my ($x) = @_;
        Sidef::Types::Bool::Bool->new(Math::GMPq::Rmpq_equal($$x, $$ONE));
    }

    sub is_positive {
        my ($x) = @_;
        Sidef::Types::Bool::Bool->new(Math::GMPq::Rmpq_sgn($$x) > 0);
    }

    *is_pos = \&is_positive;

    sub is_negative {
        my ($x) = @_;
        Sidef::Types::Bool::Bool->new(Math::GMPq::Rmpq_sgn($$x) < 0);
    }

    *is_neg = \&is_negative;

    sub _is_int {
        my ($x) = @_;

        my $dz = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_den($dz, $x);

        state $one_z = Math::GMPz::Rmpz_init_set_str(1, 10);
        Math::GMPz::Rmpz_cmp($dz, $one_z) == 0;
    }

    sub is_int {
        my ($x) = @_;
        Sidef::Types::Bool::Bool->new(_is_int($$x));
    }

    sub is_even {
        my ($x) = @_;
        _is_int($$x) or return Sidef::Types::Bool::Bool->false;

        my $nz = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_num($nz, $$x);

        Sidef::Types::Bool::Bool->new(Math::GMPz::Rmpz_even_p($nz));
    }

    sub is_odd {
        my ($x) = @_;
        _is_int($$x) or return Sidef::Types::Bool::Bool->false;

        my $nz = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_num($nz, $$x);

        Sidef::Types::Bool::Bool->new(Math::GMPz::Rmpz_odd_p($nz));
    }

    sub is_div {
        my ($x, $y) = @_;
        _valid($y);
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_mod($z, _as_int($x), _as_int($y));
        Sidef::Types::Bool::Bool->new(Math::GMPz::Rmpz_sgn($z) == 0);
    }

    sub divides {
        my ($x, $y) = @_;
        _valid($y);
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_mod($z, _as_int($y), _as_int($x));
        Sidef::Types::Bool::Bool->new(Math::GMPz::Rmpz_sgn($z) == 0);
    }

    sub is_inf {
        state $x = Sidef::Types::Bool::Bool->false;
    }

    sub is_nan {
        state $x = Sidef::Types::Bool::Bool->false;
    }

    sub max {
        my ($x, $y) = @_;
        _valid($y);
        Math::GMPq::Rmpq_cmp($$x, $$y) > 0 ? $x : $y;
    }

    sub min {
        my ($x, $y) = @_;
        _valid($y);
        Math::GMPq::Rmpq_cmp($$x, $$y) < 0 ? $x : $y;
    }

    sub int {
        my ($x) = @_;
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, $$x);
        _new(_mpz2rat($z));
    }

    *as_int = \&int;

    sub float {
        my $f = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_q($f, ${$_[0]}, $ROUND);
        _new(_mpfr2rat($f));
    }

    *as_float = \&float;

    sub rat { $_[0] }

    sub as_rat {
        Sidef::Types::String::String->new(Math::GMPq::Rmpq_get_str(${$_[0]}, 10));
    }

    *dump = \&as_rat;

    sub as_bin {
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, ${$_[0]});
        state $bigint = _load_bigint();
        Sidef::Types::String::String->new(substr(Math::BigInt->new(Math::GMPz::Rmpz_get_str($z, 10))->as_bin, 2));
    }

    sub as_oct {
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, ${$_[0]});
        state $bigint = _load_bigint();
        Sidef::Types::String::String->new(substr(Math::BigInt->new(Math::GMPz::Rmpz_get_str($z, 10))->as_oct, 1));
    }

    sub as_hex {
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, ${$_[0]});
        state $bigint = _load_bigint();
        Sidef::Types::String::String->new(substr(Math::BigInt->new(Math::GMPz::Rmpz_get_str($z, 10))->as_hex, 2));
    }

    sub bin {
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, ${$_[0]});

        my $r = Math::GMPz::Rmpz_init();
        my @digits =
          grep { $_ eq '0' or $_ eq '1' or die "[ERROR] Non-binary digit detected inside number `$z` in Number.bin()\n" }
          split(//, scalar reverse Math::GMPz::Rmpz_get_str($z, 10));

        foreach my $i (0 .. $#digits) {
            if ($digits[$i] eq '1') {
                my $tmp = Math::GMPz::Rmpz_init();
                Math::GMPz::Rmpz_ui_pow_ui($tmp, 2, $i);
                Math::GMPz::Rmpz_add($r, $r, $tmp);
            }
        }
        _new(_mpz2rat($r));
    }

    sub digits {
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, ${$_[0]});
        Math::GMPz::Rmpz_abs($z, $z);
        Sidef::Types::Array::Array->new(map { _new_uint($_) } split(//, Math::GMPz::Rmpz_get_str($z, 10)));
    }

    sub length {
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, ${$_[0]});
        _new_uint(Math::GMPz::Rmpz_sizeinbase($z, 10));
    }

    *len  = \&length;
    *size = \&length;

    sub floor {
        my ($x) = @_;
        _is_int($$x) && return $x;

        if (Math::GMPq::Rmpq_sgn($$x) > 0) {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $$x);
            _new(_mpz2rat($z));
        }
        else {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $$x);
            Math::GMPz::Rmpz_sub_ui($z, $z, 1);
            _new(_mpz2rat($z));
        }
    }

    sub ceil {
        my ($x) = @_;
        _is_int($$x) && return $x;

        if (Math::GMPq::Rmpq_sgn($$x) > 0) {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $$x);
            Math::GMPz::Rmpz_add_ui($z, $z, 1);
            _new(_mpz2rat($z));
        }
        else {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $$x);
            _new(_mpz2rat($z));
        }
    }

    sub inc {
        my ($x) = @_;
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_add($r, $$x, $$ONE);
        _new($r);
    }

    sub dec {
        my ($x) = @_;
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_sub($r, $$x, $$ONE);
        _new($r);
    }

    #
    ## Integer operations
    #

    sub iadd {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_add($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    sub isub {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_sub($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    sub imul {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_mul($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    sub idiv {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_div($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    sub mod {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_mod($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    sub modpow {
        my ($x, $y, $z) = @_;
        _valid($y, $z);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_powm($r, _as_int($x), _as_int($y), _as_int($z));
        _new(_mpz2rat($r));
    }

    sub modinv {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_invert($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    *invmod = \&modinv;

    sub divmod {
        my ($x, $y) = @_;

        _valid($y);

        my $r1 = Math::GMPz::Rmpz_init();
        my $r2 = Math::GMPz::Rmpz_init();

        Math::GMPz::Rmpz_divmod($r1, $r2, _as_int($x), _as_int($y));
        (_new(_mpz2rat($r1)), _new(_mpz2rat($r2)));
    }

    sub and {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_and($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    sub or {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_ior($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    sub xor {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_xor($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    sub not {
        my ($x) = @_;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_com($r, _as_int($x));
        _new(_mpz2rat($r));
    }

    sub factorial {
        my ($x) = @_;
        return nan() if Math::GMPq::Rmpq_sgn($$x) < 0;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_fac_ui($r, CORE::int(Math::GMPq::Rmpq_get_d($$x)));
        _new(_mpz2rat($r));
    }

    *fac = \&factorial;

    sub double_factorial {
        my ($x) = @_;
        return nan() if Math::GMPq::Rmpq_sgn($$x) < 0;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_2fac_ui($r, CORE::int(Math::GMPq::Rmpq_get_d($$x)));
        _new(_mpz2rat($r));
    }

    *dfac = \&double_factorial;

    sub primorial {
        my ($x) = @_;
        return nan() if Math::GMPq::Rmpq_sgn($$x) < 0;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_primorial_ui($r, CORE::int(Math::GMPq::Rmpq_get_d($$x)));
        _new(_mpz2rat($r));
    }

    sub fibonacci {
        my ($x) = @_;
        return nan() if Math::GMPq::Rmpq_sgn($$x) < 0;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_fib_ui($r, CORE::int(Math::GMPq::Rmpq_get_d($$x)));
        _new(_mpz2rat($r));
    }

    *fib = \&fibonacci;

    sub binomial {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_bin_si($r, _as_int($x), CORE::int(Math::GMPq::Rmpq_get_d($$y)));
        _new(_mpz2rat($r));
    }

    sub legendre {
        my ($x, $y) = @_;
        _valid($y);
        _new_int(Math::GMPz::Rmpz_legendre(_as_int($x), _as_int($y)));
    }

    sub jacobi {
        my ($x, $y) = @_;
        _valid($y);
        _new_int(Math::GMPz::Rmpz_jacobi(_as_int($x), _as_int($y)));
    }

    sub kronecker {
        my ($x, $y) = @_;
        _valid($y);
        _new_int(Math::GMPz::Rmpz_kronecker(_as_int($x), _as_int($y)));
    }

    sub lucas {
        my ($x) = @_;
        return nan() if Math::GMPq::Rmpq_sgn($$x) < 0;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_lucnum_ui($r, CORE::int(Math::GMPq::Rmpq_get_d($$x)));
        _new(_mpz2rat($r));
    }

    sub gcd {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_gcd($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    sub lcm {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_lcm($r, _as_int($x), _as_int($y));
        _new(_mpz2rat($r));
    }

    # Correct up to a maximum value of 341,550,071,728,320
    # See: https://en.wikipedia.org/wiki/Miller%E2%80%93Rabin_primality_test#Deterministic_variants_of_the_test
    sub is_prime {
        my ($x) = @_;
        Sidef::Types::Bool::Bool->new(Math::GMPz::Rmpz_probab_prime_p(_as_int($x), 7) > 0);
    }

    sub next_prime {
        my ($x) = @_;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_nextprime($r, _as_int($x));
        _new(_mpz2rat($r));
    }

    sub is_square {
        my ($x) = @_;

        _is_int($$x) or return Sidef::Types::Bool::Bool->false;

        my $nz = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_num($nz, $$x);

        Sidef::Types::Bool::Bool->new(Math::GMPz::Rmpz_perfect_square_p($nz));
    }

    *is_sqr = \&is_square;

    sub is_power {
        my ($x) = @_;

        _is_int($$x) or return Sidef::Types::Bool::Bool->false;

        my $nz = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_num($nz, $$x);

        Sidef::Types::Bool::Bool->new(Math::GMPz::Rmpz_perfect_power_p($nz));
    }

    *is_pow = \&is_power;

    sub next_pow2 {
        my ($x) = @_;

        state $one_z = do {
            my $r = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_ui($r, 1);
            $r;
        };

        my $f = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_z($f, _as_int($x), $PREC);
        Math::MPFR::Rmpfr_log2($f, $f, $ROUND);
        Math::MPFR::Rmpfr_ceil($f, $f);

        my $ui = Math::MPFR::Rmpfr_get_ui($f, $ROUND);

        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_mul_2exp($z, $one_z, $ui);
        _new(_mpz2rat($z));
    }

    *next_power2 = \&next_pow2;

    sub next_pow {
        my ($x, $y) = @_;

        _valid($y);

        my $f = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_z($f, _as_int($x), $PREC);
        Math::MPFR::Rmpfr_log($f, $f, $ROUND);

        my $f2 = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_z($f2, _as_int($y), $PREC);
        Math::MPFR::Rmpfr_log($f2, $f2, $ROUND);

        Math::MPFR::Rmpfr_div($f, $f, $f2, $ROUND);
        Math::MPFR::Rmpfr_ceil($f, $f);

        my $ui = Math::MPFR::Rmpfr_get_ui($f, $ROUND);

        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_pow_ui($z, _as_int($y), $ui);
        _new(_mpz2rat($z));
    }

    *next_power = \&next_pow;

    sub shift_left {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_mul_2exp($r, _as_int($x), CORE::int(Math::GMPq::Rmpq_get_d($$y)));
        _new(_mpz2rat($r));
    }

    sub shift_right {
        my ($x, $y) = @_;
        _valid($y);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_div_2exp($r, _as_int($x), CORE::int(Math::GMPq::Rmpq_get_d($$y)));
        _new(_mpz2rat($r));
    }

    #
    ## Rational specific
    #

    sub numerator {
        my ($x) = @_;
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_num($z, $$x);

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_z($r, $z);
        _new($r);
    }

    *nu = \&numerator;

    sub denominator {
        my ($x) = @_;
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_den($z, $$x);

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_z($r, $z);
        _new($r);
    }

    *de = \&denominator;

    sub parts {
        my ($x) = @_;
        ($x->numerator, $x->denominator);
    }

    *nude = \&parts;

    #
    ## Conversion/Miscellaneous
    #

    sub chr {
        my ($x) = @_;
        Sidef::Types::String::String->new(CORE::chr(Math::GMPq::Rmpq_get_d($$x)));
    }

    sub complex {
        my ($x, $y) = @_;

        if (defined $y) {
            _valid($y);
            Sidef::Types::Number::Complex->new($x, $y);
        }
        else {
            Sidef::Types::Number::Complex->new($x);
        }
    }

    *c = \&complex;

    sub i {
        my ($x) = @_;
        Sidef::Types::Number::Complex->new(0, $x);
    }

    sub array_to {
        my ($x, $y, $step) = @_;

        my @array;
        if (not defined($step)) {

            _valid($y);

            foreach my $i (Math::GMPq::Rmpq_get_d($$x) .. Math::GMPq::Rmpq_get_d($$y)) {
                my $n = Math::GMPq::Rmpq_init();
                Math::GMPq::Rmpq_set_str($n, $i, 10);
                push @array, _new($n);
            }
        }
        else {

            _valid($y, $step);

            my $xq    = $$x;
            my $yq    = $$y;
            my $stepq = $$step;

            my $acc = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set($acc, $xq);

            for (; Math::GMPq::Rmpq_cmp($acc, $yq) <= 0 ; Math::GMPq::Rmpq_add($acc, $acc, $stepq)) {
                my $copy = Math::GMPq::Rmpq_init();
                Math::GMPq::Rmpq_set($copy, $acc);
                push @array, _new($copy);
            }
        }

        Sidef::Types::Array::Array->new(@array);
    }

    *arr_to = \&array_to;

    sub array_downto {
        my ($x, $y, $step) = @_;

        if (not defined $step) {
            _valid($y);
            $step = $ONE;
        }
        else {
            _valid($y, $step);
        }

        my $xq    = $$x;
        my $yq    = $$y;
        my $stepq = $$step;

        my $acc = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set($acc, $xq);

        my @array;
        for (; Math::GMPq::Rmpq_cmp($acc, $yq) >= 0 ; Math::GMPq::Rmpq_sub($acc, $acc, $stepq)) {
            my $copy = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set($copy, $acc);
            push @array, _new($copy);
        }

        Sidef::Types::Array::Array->new(@array);
    }

    # TODO: find a better solution which doesn't use Math::BigRat
    sub roundf {
        my ($x, $prec) = @_;
        _valid($prec);
        my $str = Math::GMPq::Rmpq_get_str($$x, 10);
        state $bigrat = _load_bigrat();
        $x->new(Math::BigRat->new($str)->as_float(CORE::length($str))->bfround(Math::GMPq::Rmpq_get_d($$prec))->bstr);
    }

    sub to {
        my ($from, $to, $step) = @_;

        if (defined $step) {
            _valid($to, $step);
        }
        else {
            _valid($to);
        }

        Sidef::Types::Range::RangeNumber->__new__(
                                                  from => $$from,
                                                  to   => $$to,
                                                  step => (defined($step) ? $$step : $$ONE),
                                                 );
    }

    *upto = \&to;

    sub downto {
        my ($from, $to, $step) = @_;

        if (defined $step) {
            _valid($to, $step);
        }
        else {
            _valid($to);
        }

        $step = defined($step)
          ? do {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_neg($r, $$step);
            $r;
          }
          : $$MONE;

        Sidef::Types::Range::RangeNumber->__new__(
                                                  from => $$from,
                                                  to   => $$to,
                                                  step => $step,
                                                 );
    }

    sub range {
        my ($from, $to, $step) = @_;

        defined($to)
          ? $from->to($to, $step)
          : $ZERO->to($from->dec);
    }

    sub rand {
        my ($x, $y) = @_;

        if (defined $y) {
            _valid($y);
            my $min = Math::GMPq::Rmpq_get_d($$x);
            $x->new($min + CORE::rand(Math::GMPq::Rmpq_get_d($$y) - $min));
        }
        else {
            $x->new(CORE::rand(Math::GMPq::Rmpq_get_d($$x)));
        }
    }

    sub rand_int {
        my ($x, $y) = @_;

        if (defined $y) {
            _valid($y);
            my $min = Math::GMPq::Rmpq_get_d($$x);
            $x->new(CORE::int($min + CORE::rand(Math::GMPq::Rmpq_get_d($$y) - $min)));
        }
        else {
            $x->new(CORE::int(CORE::rand(Math::GMPq::Rmpq_get_d($$x))));
        }
    }

    sub of {
        my ($x, $obj) = @_;
        ref($obj) eq 'Sidef::Types::Block::Block'
          ? Sidef::Types::Array::Array->new(map { $obj->run(_new_uint($_)) } 1 .. Math::GMPq::Rmpq_get_d($$x))
          : Sidef::Types::Array::Array->new(($obj) x Math::GMPq::Rmpq_get_d($$x));
    }

    sub times {
        my ($num, $block) = @_;

        $num = $$num;
        return $block if $num < 1;

        if ($num < (-1 >> 1)) {
            foreach my $i (1 .. $num) {
                if (defined(my $res = $block->_run_code(_new_uint($i)))) {
                    return $res;
                }
            }
        }
        else {
            my $limit = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($limit, $num);

            for (my $i = Math::GMPz::Rmpz_init_set_ui(1) ;
                 Math::GMPz::Rmpz_cmp($i, $num) <= 0 ;
                 Math::GMPz::Rmpz_add_ui($i, $i, 1)) {
                my $n = Math::GMPq::Rmpq_init();
                Math::GMPq::Rmpq_set_z($n, $i);
                if (defined(my $res = $block->_run_code(_new($n)))) {
                    return $res;
                }
            }
        }

        $block;
    }

    {
        no strict 'refs';

        *{__PACKAGE__ . '::' . '/'}   = \&div;
        *{__PACKAGE__ . '::' . '÷'}  = \&div;
        *{__PACKAGE__ . '::' . '*'}   = \&mul;
        *{__PACKAGE__ . '::' . '+'}   = \&add;
        *{__PACKAGE__ . '::' . '-'}   = \&sub;
        *{__PACKAGE__ . '::' . '%'}   = \&mod;
        *{__PACKAGE__ . '::' . '**'}  = \&pow;
        *{__PACKAGE__ . '::' . '++'}  = \&inc;
        *{__PACKAGE__ . '::' . '--'}  = \&dec;
        *{__PACKAGE__ . '::' . '<'}   = \&lt;
        *{__PACKAGE__ . '::' . '>'}   = \&gt;
        *{__PACKAGE__ . '::' . '&'}   = \&and;
        *{__PACKAGE__ . '::' . '|'}   = \&or;
        *{__PACKAGE__ . '::' . '^'}   = \&xor;
        *{__PACKAGE__ . '::' . '<=>'} = \&cmp;
        *{__PACKAGE__ . '::' . '<='}  = \&le;
        *{__PACKAGE__ . '::' . '≤'} = \&le;
        *{__PACKAGE__ . '::' . '>='}  = \&ge;
        *{__PACKAGE__ . '::' . '≥'} = \&ge;
        *{__PACKAGE__ . '::' . '=='}  = \&eq;
        *{__PACKAGE__ . '::' . '!='}  = \&ne;
        *{__PACKAGE__ . '::' . '≠'} = \&ne;
        *{__PACKAGE__ . '::' . '..'}  = \&array_to;
        *{__PACKAGE__ . '::' . '...'} = \&to;
        *{__PACKAGE__ . '::' . '..^'} = \&to;
        *{__PACKAGE__ . '::' . '^..'} = \&downto;
        *{__PACKAGE__ . '::' . '!'}   = \&factorial;
        *{__PACKAGE__ . '::' . '%%'}  = \&is_div;
        *{__PACKAGE__ . '::' . '>>'}  = \&shift_right;
        *{__PACKAGE__ . '::' . '<<'}  = \&shift_left;
        *{__PACKAGE__ . '::' . '~'}   = \&not;
        *{__PACKAGE__ . '::' . ':'}   = \&complex;
        *{__PACKAGE__ . '::' . '//'}  = \&idiv;
    }
}

1
