package Sidef::Types::Number::Number {

    use utf8;
    use 5.014;

    use Math::GMPq qw();
    use Math::GMPz qw();
    use Math::MPFR qw();

    our $ROUND = Math::MPFR::MPFR_RNDN();
    our $PREC  = 128;

    my $ONE = Math::GMPq::Rmpq_init();
    Math::GMPq::Rmpq_set_ui($ONE, 1, 1);

    my $ZERO = Math::GMPq::Rmpq_init();
    Math::GMPq::Rmpq_set_ui($ZERO, 0, 1);

    my $MONE = Math::GMPq::Rmpq_init();
    Math::GMPq::Rmpq_set_si($MONE, -1, 1);

    use constant {
                  ONE  => bless(\$ONE,  __PACKAGE__),
                  ZERO => bless(\$ZERO, __PACKAGE__),
                  MONE => bless(\$MONE, __PACKAGE__),
                 };

    use parent qw(
      Sidef::Object::Object
      Sidef::Convert::Convert
      );

    use overload
      q{bool} => sub { Math::GMPq::Rmpq_sgn(${$_[0]}) != 0 },
      q{0+}   => \&get_value,
      q{""}   => \&_big2str;

    use Sidef::Types::Bool::Bool;

    my @cache;

    sub _new {
        bless(\$_[0], __PACKAGE__);
    }

    sub _new_int {
        $_[0] == -1 && return MONE;
        $_[0] >= 0  && return &_new_uint;
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_si($r, $_[0], 1);
        bless(\$r, __PACKAGE__);
    }

    sub _new_uint {
        exists($cache[$_[0]])
          && return $cache[$_[0]];
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_ui($r, $_[0], 1);
        $_[0] <= 8192
          ? ($cache[$_[0]] = bless(\$r, __PACKAGE__))
          : bless(\$r, __PACKAGE__);
    }

    sub _set_str {
        my $r = Math::GMPq::Rmpq_init();
        index($_[1], '/') == -1
          ? Math::GMPq::Rmpq_set_str($r, "$_[1]/1", 10)
          : Math::GMPq::Rmpq_set_str($r, $_[1],     10);
        bless \$r, __PACKAGE__;
    }

    sub new {
        my (undef, $num, $base) = @_;

            ref($num) eq 'Math::GMPq' ? bless(\$num, __PACKAGE__)
          : ref($num) eq __PACKAGE__ ? $num
          : do {

            $base = defined($base) ? ref($base) ? "$base" : $base : 10;

            $num = "$num"
              if (index(ref($num), 'Sidef::') == 0);

            my $r = Math::GMPq::Rmpq_init();
            my $rat = $num ? ($base == 10 && $num =~ tr/Ee.//) ? _str2rat($num) : ($num =~ tr/+//dr) : 0;
            eval { Math::GMPq::Rmpq_set_str($r, $rat, $base) };
            $@ && return nan();

            #$@ && die "[ERROR] Value <<$num>> is not a valid base-$base number";
            Math::GMPq::Rmpq_canonicalize($r) if index($rat, '/') != -1;
            bless \$r, __PACKAGE__;
          };
    }

    *call = \&new;

    sub _valid {
        (
         ref($$_) eq __PACKAGE__
           or do {
             my $sub = overload::Method($$_, '0+');

             my $tmp = (
                        defined($sub)
                        ? __PACKAGE__->new($sub->($$_))
                        : die "[ERROR] Value <<$$_>> cannot be implicitly converted to a number!"
                       );

             ref($tmp) eq __PACKAGE__
               or die "[ERROR] Cannot convert <<$$_>> to a number! (is method \"to_n\" well-defined?)";

             $$_ = $tmp;
           }
        ) for @_;
    }

    sub _big2mpfr {
        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_q($r, ${$_[0]}, $ROUND);
        $r;
    }

    sub _big2mpz {
        my $i = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($i, ${$_[0]});
        $i;
    }

    sub _mpfr2big {

        $PREC = "$PREC" if ref($PREC);

        if (Math::MPFR::Rmpfr_inf_p($_[0])) {
            if (Math::MPFR::Rmpfr_sgn($_[0]) > 0) {
                return state $x = inf();
            }
            else {
                return state $x = ninf();
            }
        }

        if (Math::MPFR::Rmpfr_nan_p($_[0])) {
            return state $x = nan();
        }

        my $r = Math::GMPq::Rmpq_init();
        Math::MPFR::Rmpfr_get_q($r, $_[0]);
        bless \$r, __PACKAGE__;
    }

    sub _mpz2big {
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_z($r, $_[0]);
        bless \$r, __PACKAGE__;
    }

    sub _str2rat {
        my $str = lc($_[0]);

        my $sign = substr($str, 0, 1);
        if ($sign eq '-') {
            substr($str, 0, 1, '');
            $sign = '-';
        }
        else {
            substr($str, 0, 1, '') if ($sign eq '+');
            $sign = '';
        }

        my $i;
        if (($i = index($str, 'e')) != -1) {

            my $exp = substr($str, $i + 1);

            # Handle specially numbers with very big exponents
            # (it's not a very good solution, but I hope it's only temporary)
            if (abs($exp) >= 1000000) {
                my $mpfr = Math::MPFR::Rmpfr_init2($PREC);
                Math::MPFR::Rmpfr_set_str($mpfr, "$sign$str", 10, $ROUND);
                my $mpq = Math::GMPq::Rmpq_init();
                Math::MPFR::Rmpfr_get_q($mpq, $mpfr);
                return Math::GMPq::Rmpq_get_str($mpq, 10);
            }

            my ($before, $after) = split(/\./, substr($str, 0, $i));

            if (not defined($after)) {    # return faster for numbers like "13e2"
                if ($exp >= 0) {
                    return ("$sign$before" . ('0' x $exp));
                }
                else {
                    $after = '';
                }
            }

            my $numerator   = "$before$after";
            my $denominator = "1";

            if ($exp < 1) {
                $denominator .= '0' x (abs($exp) + length($after));
            }
            else {
                my $diff = ($exp - length($after));
                if ($diff >= 0) {
                    $numerator .= '0' x $diff;
                }
                else {
                    my $s = "$before$after";
                    substr($s, $exp + length($before), 0, '.');
                    return _str2rat("$sign$s");
                }
            }

            "$sign$numerator/$denominator";
        }
        elsif (($i = index($str, '.')) != -1) {
            my ($before, $after) = (substr($str, 0, $i), substr($str, $i + 1));
            if (($after =~ tr/0//) == length($after)) {
                return "$sign$before";
            }
            $sign . ("$before$after/1" =~ s/^0+//r) . ('0' x length($after));
        }
        else {
            "$sign$str";
        }
    }

    sub get_value { Math::GMPq::Rmpq_get_d(${$_[0]}) }

    sub _big2str {
        Math::GMPq::Rmpq_integer_p(${$_[0]})
          ? Math::GMPq::Rmpq_get_str(${$_[0]}, 10)
          : do {
            my ($str, $exp) = Math::MPFR::Rmpfr_deref2(_big2mpfr($_[0]), 10, CORE::int($PREC / 4), $ROUND);

            my $neg = CORE::chr(CORE::ord($str)) eq '-' ? 1 : 0;

            if (CORE::abs($exp) >= length($str)) {
                substr($str, 1 + $neg, 0, '.');
                return $str . 'e' . ($exp - 1);
            }

            substr($str, 0, 1, '') if $neg;

            if ($exp > 0) {
                substr($str, $exp, 0, '.');
            }
            else {
                substr($str, 0, 0, '0.' . ('0' x CORE::abs($exp)));
            }

            substr($str, -1) eq '0'
              and $str =~ s/0+\z//;

            $neg ? "-$str" : $str;
          };
    }

    sub base {
        my ($x, $y) = @_;
        _valid(\$y);

        state $min = Math::GMPq->new(2);
        state $max = Math::GMPq->new(36);

        if (Math::GMPq::Rmpq_cmp($$y, $min) < 0 or Math::GMPq::Rmpq_cmp($$y, $max) > 0) {
            die "[ERROR] base must be between 2 and 36, got $$y\n";
        }

        Sidef::Types::String::String->new(Math::GMPq::Rmpq_get_str(${$_[0]}, $$y));
    }

    *in_base = \&base;

    sub _get_frac {
        Math::GMPq::Rmpq_get_str(${$_[0]}, 10);
    }

    sub _get_double {
        Math::GMPq::Rmpq_get_d(${$_[0]});
    }

    #
    ## Constants
    #

    sub pi {
        my $pi = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_const_pi($pi, $ROUND);
        _mpfr2big($pi);
    }

    sub tau {
        my $tau = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_const_pi($tau, $ROUND);
        Math::MPFR::Rmpfr_mul_ui($tau, $tau, 2, $ROUND);
        _mpfr2big($tau);
    }

    sub ln2 {
        my $ln2 = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_const_log2($ln2, $ROUND);
        _mpfr2big($ln2);
    }

    sub Y {
        my $euler = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_const_euler($euler, $ROUND);
        _mpfr2big($euler);
    }

    sub G {
        my $catalan = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_const_catalan($catalan, $ROUND);
        _mpfr2big($catalan);
    }

    sub e {
        state $one_f = (Math::MPFR::Rmpfr_init_set_ui(1, $ROUND))[0];
        my $e = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_exp($e, $one_f, $ROUND);
        _mpfr2big($e);
    }

    sub phi {
        state $five4_f = (Math::MPFR::Rmpfr_init_set_str("1.25", 10, $ROUND))[0];
        state $half_f  = (Math::MPFR::Rmpfr_init_set_str("0.5",  10, $ROUND))[0];

        my $phi = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_sqrt($phi, $five4_f, $ROUND);
        Math::MPFR::Rmpfr_add($phi, $phi, $half_f, $ROUND);

        _mpfr2big($phi);
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
        elsif (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $y;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_add($r, $$x, $$y);
        bless \$r, __PACKAGE__;
    }

    sub iadd {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_add($r, $r, _big2mpz($y));
        _mpz2big($r);
    }

    sub sub {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return $y->new($x)->sub($y);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $y->neg;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_sub($r, $$x, $$y);
        bless \$r, __PACKAGE__;
    }

    sub isub {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_sub($r, $r, _big2mpz($y));
        _mpz2big($r);
    }

    sub mul {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return $y->mul($x);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            my $sign = Math::GMPq::Rmpq_sgn($$x);
            return ($sign < 0 ? $y->neg : $sign > 0 ? $y : nan());
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_mul($r, $$x, $$y);
        bless \$r, __PACKAGE__;
    }

    sub imul {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_mul($r, $r, _big2mpz($y));
        _mpz2big($r);
    }

    sub div {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return $y->new($x)->div($y);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (ZERO);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        if (!Math::GMPq::Rmpq_sgn($$y)) {
            my $sign = Math::GMPq::Rmpq_sgn($$x);
            return (!$sign ? nan() : $sign > 0 ? inf() : ninf());
        }

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_div($r, $$x, $$y);
        bless \$r, __PACKAGE__;
    }

    sub idiv {
        my ($x, $y) = @_;
        _valid(\$y);

        my $r = _big2mpz($x);
        $y = _big2mpz($y);

        if (!Math::GMPz::Rmpz_sgn($y)) {
            my $sign = Math::GMPz::Rmpz_sgn($r);
            return (!$sign ? nan() : $sign > 0 ? inf() : ninf());
        }

        Math::GMPz::Rmpz_div($r, $r, $y);
        _mpz2big($r);
    }

    sub neg {
        my ($x) = @_;
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_neg($r, $$x);
        bless \$r, __PACKAGE__;
    }

    *negative = \&neg;

    sub abs {
        my $q = ${$_[0]};
        Math::GMPq::Rmpq_sgn($q) >= 0 and return ($_[0]);
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_abs($r, $q);
        bless \$r, __PACKAGE__;
    }

    *pos      = \&abs;
    *positive = \&abs;

    sub inv {
        my ($x) = @_;

        # Return Inf when x is zero
        if (!Math::GMPq::Rmpq_sgn($$x)) {
            return inf();
        }

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_inv($r, $$x);
        bless \$r, __PACKAGE__;
    }

    sub sqrt {
        my ($x) = @_;

        # Return a complex number for x < 0
        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->sqrt;
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_sqrt($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub isqrt {
        my ($x)    = @_;
        my $r      = _big2mpz($x);
        my $is_neg = Math::GMPz::Rmpz_sgn($r) < 0;
        Math::GMPz::Rmpz_abs($r, $r) if $is_neg;
        Math::GMPz::Rmpz_sqrt($r, $r);

        $is_neg
          ? Sidef::Types::Number::Complex->new(0, _mpz2big($r))
          : _mpz2big($r);
    }

    sub cbrt {
        my ($x) = @_;

        # Return a complex number for x < 0
        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->cbrt;
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_cbrt($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub root {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return $y->new($x)->pow($y->inv);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (ONE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);
        return $x->pow($y->inv);
    }

    sub iroot {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (ONE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        my $r    = _big2mpz($x);
        my $root = CORE::int(Math::GMPq::Rmpq_get_d($$y));

        my ($is_even, $is_neg) = $root % 2 == 0;
        ($is_neg = Math::GMPz::Rmpz_sgn($r) < 0) if $is_even;
        Math::GMPz::Rmpz_abs($r, $r) if ($is_even && $is_neg);
        Math::GMPz::Rmpz_root($r, $r, $root);

        $is_even && $is_neg
          ? Sidef::Types::Number::Complex->new(0, _mpz2big($r))
          : _mpz2big($r);
    }

    sub sqr {
        my ($x) = @_;
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_mul($r, $$x, $$x);
        bless \$r, __PACKAGE__;
    }

    sub pow {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return $y->new($x)->pow($y);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Inf') {
            return (($x->is_one || $x->is_mone) ? (ONE) : $x->is_zero ? (ZERO) : $y);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (($x->is_one || $x->is_mone) ? (ONE) : $x->is_zero ? inf() : (ZERO));
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        if (Math::GMPq::Rmpq_integer_p($$x) and Math::GMPq::Rmpq_integer_p($$y)) {

            my $pow = Math::GMPq::Rmpq_get_d($$y);

            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $$x);
            Math::GMPz::Rmpz_pow_ui($z, $z, CORE::abs($pow));

            my $q = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_z($q, $z);

            if ($pow < 0) {
                if (!Math::GMPq::Rmpq_sgn($q)) {
                    return inf();
                }
                Math::GMPq::Rmpq_inv($q, $q);
            }

            return bless \$q, __PACKAGE__;
        }

        if (Math::GMPq::Rmpq_sgn($$x) < 0 and !Math::GMPq::Rmpq_integer_p($$y)) {
            return Sidef::Types::Number::Complex->new($x)->pow($y);
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_pow($r, $r, _big2mpfr($y), $ROUND);
        _mpfr2big($r);
    }

    sub ipow {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $x->int->pow($y);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        state $ONE_Z = Math::GMPz::Rmpz_init_set_ui(1);
        my $pow = CORE::int(Math::GMPq::Rmpq_get_d($$y));

        my $z = _big2mpz($x);
        Math::GMPz::Rmpz_pow_ui($z, $z, CORE::abs($pow));

        if ($pow < 0) {
            return inf() if !Math::GMPz::Rmpz_sgn($z);
            Math::GMPz::Rmpz_div($z, $ONE_Z, $z);
        }

        _mpz2big($z);
    }

    sub fmod {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_fmod($r, $r, _big2mpfr($y), $ROUND);
        _mpfr2big($r);
    }

    sub log {
        my ($x, $y) = @_;

        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->log($y);
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_log($r, $r, $ROUND);

        if (defined $y) {

            if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
                return (ZERO);
            }
            elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
                return nan();
            }

            _valid(\$y);
            my $baseln = _big2mpfr($y);
            Math::MPFR::Rmpfr_log($baseln, $baseln, $ROUND);
            Math::MPFR::Rmpfr_div($r, $r, $baseln, $ROUND);
        }

        _mpfr2big($r);
    }

    sub ln {
        my ($x) = @_;

        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->ln;
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_log($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub log2 {
        my ($x) = @_;

        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->log2;
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_log2($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub log10 {
        my ($x) = @_;

        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->log10;
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_log10($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub exp {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_exp($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub exp2 {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_exp2($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub exp10 {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_exp10($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## Trigonometric functions
    #

    sub sin {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_sin($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub asin {
        my ($x) = @_;

        # Return a complex number for x < -1 or x > 1
        if (Math::GMPq::Rmpq_cmp_ui($$x, 1, 1) > 0 or Math::GMPq::Rmpq_cmp_si($$x, -1, 1) < 0) {
            return Sidef::Types::Number::Complex->new($x)->asin;
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_asin($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub sinh {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_sinh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub asinh {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_asinh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub cos {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_cos($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub acos {
        my ($x) = @_;

        # Return a complex number for x < -1 or x > 1
        if (Math::GMPq::Rmpq_cmp_ui($$x, 1, 1) > 0 or Math::GMPq::Rmpq_cmp_si($$x, -1, 1) < 0) {
            return Sidef::Types::Number::Complex->new($x)->acos;
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_acos($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub cosh {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_cosh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub acosh {
        my ($x) = @_;

        # Return a complex number for x < 1
        if (Math::GMPq::Rmpq_cmp_ui($$x, 1, 1) < 0) {
            return Sidef::Types::Number::Complex->new($x)->acosh;
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_acosh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub tan {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_tan($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub atan {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_atan($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub tanh {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_tanh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub atanh {
        my ($x) = @_;

        # Return a complex number for x <= -1 or x >= 1
        if (Math::GMPq::Rmpq_cmp_ui($$x, 1, 1) >= 0 or Math::GMPq::Rmpq_cmp_si($$x, -1, 1) <= 0) {
            return Sidef::Types::Number::Complex->new($x)->atanh;
        }

        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_atanh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub sec {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_sec($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## asec(x) = acos(1/x)
    #
    sub asec {
        my ($x) = @_;

        # Return a complex number for x > -1 and x < 1
        if (Math::GMPq::Rmpq_cmp_ui($$x, 1, 1) < 0 and Math::GMPq::Rmpq_cmp_si($$x, -1, 1) > 0) {
            return Sidef::Types::Number::Complex->new($x)->asec;
        }

        state $one = Math::MPFR->new(1);
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_div($r, $one, $r, $ROUND);
        Math::MPFR::Rmpfr_acos($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub sech {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_sech($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## asech(x) = acosh(1/x)
    #
    sub asech {
        my ($x) = @_;

        # Return a complex number for x < 0 or x > 1
        if (Math::GMPq::Rmpq_cmp_ui($$x, 1, 1) > 0 or Math::GMPq::Rmpq_cmp_ui($$x, 0, 1) < 0) {
            return Sidef::Types::Number::Complex->new($x)->asech;
        }

        state $one = Math::MPFR->new(1);
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_div($r, $one, $r, $ROUND);
        Math::MPFR::Rmpfr_acosh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub csc {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_csc($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## acsc(x) = asin(1/x)
    #
    sub acsc {
        my ($x) = @_;

        # Return a complex number for x > -1 and x < 1
        if (Math::GMPq::Rmpq_cmp_ui($$x, 1, 1) < 0 and Math::GMPq::Rmpq_cmp_si($$x, -1, 1) > 0) {
            return Sidef::Types::Number::Complex->new($x)->acsc;
        }

        state $one = Math::MPFR->new(1);
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_div($r, $one, $r, $ROUND);
        Math::MPFR::Rmpfr_asin($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub csch {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_csch($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## acsch(x) = asinh(1/x)
    #
    sub acsch {
        my ($x) = @_;
        state $one = Math::MPFR->new(1);
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_div($r, $one, $r, $ROUND);
        Math::MPFR::Rmpfr_asinh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub cot {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_cot($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## acot(x) = atan(1/x)
    #
    sub acot {
        my ($x) = @_;
        state $one = Math::MPFR->new(1);
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_div($r, $one, $r, $ROUND);
        Math::MPFR::Rmpfr_atan($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub coth {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_coth($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## acoth(x) = atanh(1/x)
    #
    sub acoth {
        my ($x) = @_;
        state $one = Math::MPFR->new(1);
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_div($r, $one, $r, $ROUND);
        Math::MPFR::Rmpfr_atanh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub atan2 {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Complex') {
            return Sidef::Types::Number::Complex->new($x)->atan2($y);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Inf') {
            return (ZERO);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            if (Math::GMPq::Rmpq_sgn($$x) >= 0) {
                return pi();
            }
            else {
                return pi()->neg;
            }
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_atan2($r, $r, _big2mpfr($y), $ROUND);
        _mpfr2big($r);
    }

    #
    ## Special functions
    #

    sub agm {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_agm($r, $r, _big2mpfr($y), $ROUND);
        _mpfr2big($r);
    }

    sub hypot {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_hypot($r, $r, _big2mpfr($y), $ROUND);
        _mpfr2big($r);
    }

    sub gamma {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_gamma($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub lngamma {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_lngamma($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub lgamma {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_lgamma($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub digamma {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_digamma($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub zeta {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_zeta($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub erf {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_erf($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub erfc {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_erfc($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub eint {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_eint($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub li2 {
        my ($x) = @_;
        my $r = _big2mpfr($x);
        Math::MPFR::Rmpfr_li2($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## Comparison and testing operations
    #

    sub eq {
        my ($x, $y) = @_;
        _valid(\$y);
        if (Math::GMPq::Rmpq_equal($$x, $$y)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub ne {
        my ($x, $y) = @_;
        _valid(\$y);
        if (Math::GMPq::Rmpq_equal($$x, $$y)) {
            (Sidef::Types::Bool::Bool::FALSE);
        }
        else {
            (Sidef::Types::Bool::Bool::TRUE);
        }
    }

    sub cmp {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return (MONE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (ONE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return;
        }

        _valid(\$y);
        my $cmp = Math::GMPq::Rmpq_cmp($$x, $$y);
        !$cmp ? (ZERO) : $cmp < 0 ? (MONE) : (ONE);
    }

    sub acmp {
        my ($x, $y) = @_;

        _valid(\$y);

        my $xn = $$x;
        my $yn = $$y;

        if (Math::GMPq::Rmpq_sgn($xn) < 0) {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_abs($r, $xn);
            $xn = $r;
        }

        if (Math::GMPq::Rmpq_sgn($yn) < 0) {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_abs($r, $yn);
            $yn = $r;
        }

        my $cmp = Math::GMPq::Rmpq_cmp($xn, $yn);
        !$cmp ? (ZERO) : $cmp < 0 ? (MONE) : (ONE);
    }

    sub gt {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return (Sidef::Types::Bool::Bool::FALSE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (Sidef::Types::Bool::Bool::TRUE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return (Sidef::Types::Bool::Bool::FALSE);
        }

        _valid(\$y);

        if (Math::GMPq::Rmpq_cmp($$x, $$y) > 0) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub ge {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return (Sidef::Types::Bool::Bool::FALSE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (Sidef::Types::Bool::Bool::TRUE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return (Sidef::Types::Bool::Bool::FALSE);
        }

        _valid(\$y);

        if (Math::GMPq::Rmpq_cmp($$x, $$y) >= 0) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub lt {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return (Sidef::Types::Bool::Bool::TRUE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (Sidef::Types::Bool::Bool::FALSE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return (Sidef::Types::Bool::Bool::FALSE);
        }

        _valid(\$y);

        if (Math::GMPq::Rmpq_cmp($$x, $$y) < 0) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub le {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return (Sidef::Types::Bool::Bool::TRUE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (Sidef::Types::Bool::Bool::FALSE);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return (Sidef::Types::Bool::Bool::FALSE);
        }

        _valid(\$y);

        if (Math::GMPq::Rmpq_cmp($$x, $$y) <= 0) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub is_zero {
        my ($x) = @_;
        if (!Math::GMPq::Rmpq_sgn($$x)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub is_one {
        my ($x) = @_;
        if (Math::GMPq::Rmpq_equal($$x, $ONE)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub is_mone {
        my ($x) = @_;
        if (Math::GMPq::Rmpq_equal($$x, $MONE)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub is_positive {
        my ($x) = @_;
        if (Math::GMPq::Rmpq_sgn($$x) > 0) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    *is_pos = \&is_positive;

    sub is_negative {
        my ($x) = @_;
        if (Math::GMPq::Rmpq_sgn($$x) < 0) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    *is_neg = \&is_negative;

    sub sign {
        my ($x) = @_;
        my $sign = Math::GMPq::Rmpq_sgn($$x);
        if ($sign > 0) {
            state $z = Sidef::Types::String::String->new('+');
        }
        elsif (!$sign) {
            state $z = Sidef::Types::String::String->new('');
        }
        else {
            state $z = Sidef::Types::String::String->new('-');
        }
    }

    sub is_int {
        my ($x) = @_;
        if (Math::GMPq::Rmpq_integer_p($$x)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub is_real {
        my ($x) = @_;
        (Sidef::Types::Bool::Bool::TRUE);
    }

    sub is_even {
        my ($x) = @_;

        if (!Math::GMPq::Rmpq_integer_p($$x)) {
            return (Sidef::Types::Bool::Bool::FALSE);
        }

        my $nz = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_num($nz, $$x);

        if (Math::GMPz::Rmpz_even_p($nz)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub is_odd {
        my ($x) = @_;

        if (!Math::GMPq::Rmpq_integer_p($$x)) {
            return (Sidef::Types::Bool::Bool::FALSE);
        }

        my $nz = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_num($nz, $$x);

        if (Math::GMPz::Rmpz_odd_p($nz)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub is_div {
        my ($x, $y) = @_;
        _valid(\$y);

        return Sidef::Types::Bool::Bool::FALSE
          if Math::GMPq::Rmpq_sgn($$y) == 0;

        #---------------------------------------------------------------------------------
        ## Optimization for integers, but it turns out to be slower for small integers...
        #---------------------------------------------------------------------------------
        #~ if (Math::GMPq::Rmpq_integer_p($$x) and Math::GMPq::Rmpq_integer_p($$y)) {
        #~     if (Math::GMPz::Rmpz_divisible_p(_big2mpz($x), _big2mpz($y))) {
        #~         return (Sidef::Types::Bool::Bool::TRUE);
        #~     }
        #~     else {
        #~         return (Sidef::Types::Bool::Bool::FALSE);
        #~     }
        #~ }

        my $q = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_div($q, $$x, $$y);

        if (Math::GMPq::Rmpq_integer_p($q)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub divides {
        my ($x, $y) = @_;
        _valid(\$y);

        return Sidef::Types::Bool::Bool::FALSE
          if Math::GMPq::Rmpq_sgn($$x) == 0;

        my $q = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_div($q, $$y, $$x);

        if (Math::GMPq::Rmpq_integer_p($q)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub is_inf {
        (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_nan {
        (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_ninf {
        (Sidef::Types::Bool::Bool::FALSE);
    }

    sub max {
        my ($x, $y) = @_;
        _valid(\$y);
        Math::GMPq::Rmpq_cmp($$x, $$y) > 0 ? $x : $y;
    }

    sub min {
        my ($x, $y) = @_;
        _valid(\$y);
        Math::GMPq::Rmpq_cmp($$x, $$y) < 0 ? $x : $y;
    }

    sub int {
        my $q = ${$_[0]};
        Math::GMPq::Rmpq_integer_p($q) && return ($_[0]);
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, $q);
        _mpz2big($z);
    }

    sub float {
        my $f = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_q($f, ${$_[0]}, $ROUND);
        _mpfr2big($f);
    }

    sub rat { $_[0] }

    *re   = \&rat;
    *real = \&rat;

    sub imag { ZERO }

    *im        = \&imag;
    *imaginary = \&imag;

    sub as_int {
        my ($x, $base) = @_;

        if (defined $base) {
            _valid(\$base);
            $base = CORE::int(Math::GMPq::Rmpq_get_d($$base));
            if ($base < 2 or $base > 36) {
                die "[ERROR] base must be between 2 and 36, got $base\n";
            }
        }
        else {
            $base = 10;
        }

        my $q = $$x;
        Math::GMPq::Rmpq_integer_p($q)
          && return (Sidef::Types::String::String->new(Math::GMPq::Rmpq_get_str($q, $base)));

        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, $q);
        Sidef::Types::String::String->new(Math::GMPz::Rmpz_get_str($z, $base));
    }

    sub as_float {
        my ($x, $prec) = @_;

        if (defined $prec) {
            _valid(\$prec);
            $prec = Math::GMPq::Rmpq_get_d($$prec);
        }
        else {
            $prec = $Sidef::Types::Number::Number::PREC / 4;
        }

        local $Sidef::Types::Number::Number::PREC = 4 * $prec;
        Sidef::Types::String::String->new("$x");
    }

    sub as_rat {
        Sidef::Types::String::String->new(Math::GMPq::Rmpq_get_str(${$_[0]}, 10));
    }

    *dump = \&as_rat;

    sub as_frac {
        my $rat = Math::GMPq::Rmpq_get_str(${$_[0]}, 10);
        Sidef::Types::String::String->new(index($rat, '/') != -1 ? $rat : "$rat/1");
    }

    sub as_bin {
        my $q = ${$_[0]};
        my $str =
            Math::GMPq::Rmpq_integer_p($q)
          ? Math::GMPq::Rmpq_get_str($q, 2)
          : do {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $q);
            Math::GMPz::Rmpz_get_str($z, 2);
          };
        Sidef::Types::String::String->new($str);
    }

    sub as_oct {
        my $q = ${$_[0]};
        my $str =
            Math::GMPq::Rmpq_integer_p($q)
          ? Math::GMPq::Rmpq_get_str($q, 8)
          : do {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $q);
            Math::GMPz::Rmpz_get_str($z, 8);
          };
        Sidef::Types::String::String->new($str);
    }

    sub as_hex {
        my $q = ${$_[0]};
        my $str =
            Math::GMPq::Rmpq_integer_p($q)
          ? Math::GMPq::Rmpq_get_str($q, 16)
          : do {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $q);
            Math::GMPz::Rmpz_get_str($z, 16);
          };
        Sidef::Types::String::String->new($str);
    }

    sub digits {
        my $q = ${$_[0]};

        my $str =
            Math::GMPq::Rmpq_integer_p($q)
          ? Math::GMPq::Rmpq_get_str($q, 10)
          : do {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $q);
            Math::GMPz::Rmpz_get_str($z, 10);
          };

        $str =~ tr/-//d;
        Sidef::Types::Array::Array->new([map { _new_uint($_) } split(//, $str)]);
    }

    sub digit {
        my ($x, $y) = @_;
        _valid(\$y);

        my $q = $$x;
        my $str =
            Math::GMPq::Rmpq_integer_p($q)
          ? Math::GMPq::Rmpq_get_str($q, 10)
          : do {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $q);
            Math::GMPz::Rmpz_get_str($z, 10);
          };

        $str =~ tr/-//d;
        my $digit = substr($str, Math::GMPq::Rmpq_get_d($$y), 1);
        length($digit) ? _new_uint($digit) : nan();
    }

    sub length {
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, ${$_[0]});
        Math::GMPz::Rmpz_abs($z, $z);

        #_new_uint(Math::GMPz::Rmpz_sizeinbase($z, 10));        # turned out to be inexact
        _new_uint(Math::GMPz::Rmpz_snprintf(my $buf, 0, "%Zd", $z, 0));
    }

    *len  = \&length;
    *size = \&length;

    sub floor {
        my ($x) = @_;
        Math::GMPq::Rmpq_integer_p($$x) && return $x;

        if (Math::GMPq::Rmpq_sgn($$x) > 0) {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $$x);
            _mpz2big($z);
        }
        else {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $$x);
            Math::GMPz::Rmpz_sub_ui($z, $z, 1);
            _mpz2big($z);
        }
    }

    sub ceil {
        my ($x) = @_;
        Math::GMPq::Rmpq_integer_p($$x) && return $x;

        if (Math::GMPq::Rmpq_sgn($$x) > 0) {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $$x);
            Math::GMPz::Rmpz_add_ui($z, $z, 1);
            _mpz2big($z);
        }
        else {
            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $$x);
            _mpz2big($z);
        }
    }

    sub inc {
        my ($x) = @_;
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_add($r, $$x, $ONE);
        bless \$r, __PACKAGE__;
    }

    sub dec {
        my ($x) = @_;
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_sub($r, $$x, $ONE);
        bless \$r, __PACKAGE__;
    }

    #
    ## Integer operations
    #

    sub mod {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (Math::GMPq::Rmpq_sgn($$x) == Math::GMPq::Rmpq_sgn($$y) ? $x : $y);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        if (Math::GMPq::Rmpq_integer_p($$x) and Math::GMPq::Rmpq_integer_p($$y)) {

            my $yz     = _big2mpz($y);
            my $sign_y = Math::GMPz::Rmpz_sgn($yz);
            return nan() if !$sign_y;

            my $r = _big2mpz($x);
            Math::GMPz::Rmpz_mod($r, $r, $yz);
            if (!Math::GMPz::Rmpz_sgn($r)) {
                return (ZERO);
            }
            elsif ($sign_y < 0) {
                Math::GMPz::Rmpz_add($r, $r, $yz);
            }
            _mpz2big($r);
        }
        else {
            my $r  = _big2mpfr($x);
            my $yf = _big2mpfr($y);
            Math::MPFR::Rmpfr_fmod($r, $r, $yf, $ROUND);
            my $sign = Math::MPFR::Rmpfr_sgn($r);
            if (!$sign) {
                return (ZERO);
            }
            elsif ($sign > 0 xor Math::MPFR::Rmpfr_sgn($yf) > 0) {
                Math::MPFR::Rmpfr_add($r, $r, $yf, $ROUND);
            }
            _mpfr2big($r);
        }
    }

    sub imod {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (Math::GMPq::Rmpq_sgn($$x) == Math::GMPq::Rmpq_sgn($$y) ? $x : $y);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        my $yz     = _big2mpz($y);
        my $sign_y = Math::GMPz::Rmpz_sgn($yz);
        return nan() if !$sign_y;

        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_mod($r, $r, $yz);
        if (!Math::GMPz::Rmpz_sgn($r)) {
            return (ZERO);    # return faster
        }
        elsif ($sign_y < 0) {
            Math::GMPz::Rmpz_add($r, $r, $yz);
        }
        _mpz2big($r);
    }

    sub modpow {
        my ($x, $y, $z) = @_;
        _valid(\$y, \$z);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_powm($r, $r, _big2mpz($y), _big2mpz($z));
        _mpz2big($r);
    }

    *expmod = \&modpow;

    sub modinv {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_invert($r, $r, _big2mpz($y)) || return nan();
        _mpz2big($r);
    }

    *invmod = \&modinv;

    sub divmod {
        my ($x, $y) = @_;

        _valid(\$y);

        my $r1 = _big2mpz($x);
        my $r2 = _big2mpz($y);

        return (nan(), nan()) if !Math::GMPz::Rmpz_sgn($r2);

        Math::GMPz::Rmpz_divmod($r1, $r2, $r1, $r2);
        (_mpz2big($r1), _mpz2big($r2));
    }

    sub and {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_and($r, $r, _big2mpz($y));
        _mpz2big($r);
    }

    sub or {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_ior($r, $r, _big2mpz($y));
        _mpz2big($r);
    }

    sub xor {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_xor($r, $r, _big2mpz($y));
        _mpz2big($r);
    }

    sub not {
        my ($x) = @_;
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_com($r, $r);
        _mpz2big($r);
    }

    sub factorial {
        my ($x) = @_;
        return nan() if Math::GMPq::Rmpq_sgn($$x) < 0;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_fac_ui($r, CORE::int(Math::GMPq::Rmpq_get_d($$x)));
        _mpz2big($r);
    }

    *fac = \&factorial;

    sub double_factorial {
        my ($x) = @_;
        return nan() if Math::GMPq::Rmpq_sgn($$x) < 0;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_2fac_ui($r, CORE::int(Math::GMPq::Rmpq_get_d($$x)));
        _mpz2big($r);
    }

    *dfac = \&double_factorial;

    sub primorial {
        my ($x) = @_;
        return nan() if Math::GMPq::Rmpq_sgn($$x) < 0;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_primorial_ui($r, CORE::int(Math::GMPq::Rmpq_get_d($$x)));
        _mpz2big($r);
    }

    sub fibonacci {
        my ($x) = @_;
        return nan() if Math::GMPq::Rmpq_sgn($$x) < 0;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_fib_ui($r, CORE::int(Math::GMPq::Rmpq_get_d($$x)));
        _mpz2big($r);
    }

    *fib = \&fibonacci;

    sub binomial {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_bin_si($r, $r, CORE::int(Math::GMPq::Rmpq_get_d($$y)));
        _mpz2big($r);
    }

    *nok = \&binomial;

    sub legendre {
        my ($x, $y) = @_;
        _valid(\$y);
        _new_int(Math::GMPz::Rmpz_legendre(_big2mpz($x), _big2mpz($y)));
    }

    sub jacobi {
        my ($x, $y) = @_;
        _valid(\$y);
        _new_int(Math::GMPz::Rmpz_jacobi(_big2mpz($x), _big2mpz($y)));
    }

    sub kronecker {
        my ($x, $y) = @_;
        _valid(\$y);
        _new_int(Math::GMPz::Rmpz_kronecker(_big2mpz($x), _big2mpz($y)));
    }

    sub lucas {
        my ($x) = @_;
        return nan() if Math::GMPq::Rmpq_sgn($$x) < 0;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_lucnum_ui($r, CORE::int(Math::GMPq::Rmpq_get_d($$x)));
        _mpz2big($r);
    }

    sub gcd {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_gcd($r, $r, _big2mpz($y));
        _mpz2big($r);
    }

    sub lcm {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_lcm($r, $r, _big2mpz($y));
        _mpz2big($r);
    }

    # By default, the test is correct up to a maximum value of 341,550,071,728,320
    # See: https://en.wikipedia.org/wiki/Miller%E2%80%93Rabin_primality_test#Deterministic_variants_of_the_test
    sub is_prime {
        my ($x, $k) = @_;
        if (
            Math::GMPz::Rmpz_probab_prime_p(_big2mpz($x),
                                            defined($k)
                                            ? do { _valid(\$k); CORE::int Math::GMPq::Rmpq_get_d($$k) }
                                            : 7) > 0
          ) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    sub next_prime {
        my ($x) = @_;
        my $r = _big2mpz($x);
        Math::GMPz::Rmpz_nextprime($r, $r);
        _mpz2big($r);
    }

    sub is_square {
        my ($x) = @_;

        if (!Math::GMPq::Rmpq_integer_p($$x)) {
            return (Sidef::Types::Bool::Bool::FALSE);
        }

        my $nz = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_num($nz, $$x);

        if (Math::GMPz::Rmpz_perfect_square_p($nz)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    *is_sqr = \&is_square;

    sub is_power {
        my ($x) = @_;

        if (!Math::GMPq::Rmpq_integer_p($$x)) {
            return (Sidef::Types::Bool::Bool::FALSE);
        }

        my $nz = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_num($nz, $$x);

        if (Math::GMPz::Rmpz_perfect_power_p($nz)) {
            (Sidef::Types::Bool::Bool::TRUE);
        }
        else {
            (Sidef::Types::Bool::Bool::FALSE);
        }
    }

    *is_pow = \&is_power;

    sub next_pow2 {
        my ($x) = @_;

        state $one_z = Math::GMPz::Rmpz_init_set_ui(1);

        my $f = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_z($f, _big2mpz($x), $PREC);
        Math::MPFR::Rmpfr_log2($f, $f, $ROUND);
        Math::MPFR::Rmpfr_ceil($f, $f);

        my $ui = Math::MPFR::Rmpfr_get_ui($f, $ROUND);

        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_mul_2exp($z, $one_z, $ui);
        _mpz2big($z);
    }

    *next_power2 = \&next_pow2;

    sub next_pow {
        my ($x, $y) = @_;

        _valid(\$y);

        my $f = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_z($f, _big2mpz($x), $PREC);
        Math::MPFR::Rmpfr_log($f, $f, $ROUND);

        my $f2 = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_z($f2, _big2mpz($y), $PREC);
        Math::MPFR::Rmpfr_log($f2, $f2, $ROUND);

        Math::MPFR::Rmpfr_div($f, $f, $f2, $ROUND);
        Math::MPFR::Rmpfr_ceil($f, $f);

        my $ui = Math::MPFR::Rmpfr_get_ui($f, $ROUND);

        my $z = _big2mpz($y);
        Math::GMPz::Rmpz_pow_ui($z, $z, $ui);
        _mpz2big($z);
    }

    *next_power = \&next_pow;

    sub shift_left {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        my $i = CORE::int(Math::GMPq::Rmpq_get_d($$y));
        if ($i < 0) {
            Math::GMPz::Rmpz_div_2exp($r, $r, CORE::abs($i));
        }
        else {
            Math::GMPz::Rmpz_mul_2exp($r, $r, $i);
        }
        _mpz2big($r);
    }

    sub shift_right {
        my ($x, $y) = @_;
        _valid(\$y);
        my $r = _big2mpz($x);
        my $i = CORE::int(Math::GMPq::Rmpq_get_d($$y));
        if ($i < 0) {
            Math::GMPz::Rmpz_mul_2exp($r, $r, CORE::abs($i));
        }
        else {
            Math::GMPz::Rmpz_div_2exp($r, $r, $i);
        }
        _mpz2big($r);
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
        bless \$r, __PACKAGE__;
    }

    *nu = \&numerator;

    sub denominator {
        my ($x) = @_;
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_get_den($z, $$x);

        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_z($r, $z);
        bless \$r, __PACKAGE__;
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
            Sidef::Types::Number::Complex->new($x, $y);
        }
        else {
            Sidef::Types::Number::Complex->new($x);
        }
    }

    *c = \&complex;

    sub i {
        my ($x) = @_;
        state $i = Sidef::Types::Number::Complex->i;
        $i->mul($x);
    }

    sub round {
        my ($x, $prec) = @_;
        _valid(\$prec);

        my $nth = -CORE::int(Math::GMPq::Rmpq_get_d($$prec));
        my $sgn = Math::GMPq::Rmpq_sgn($$x);

        my $n = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set($n, $$x);
        Math::GMPq::Rmpq_abs($n, $n) if $sgn < 0;

        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_ui_pow_ui($z, 10, CORE::abs($nth));

        my $p = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_z($p, $z);

        if ($nth < 0) {
            Math::GMPq::Rmpq_div($n, $n, $p);
        }
        else {
            Math::GMPq::Rmpq_mul($n, $n, $p);
        }

        state $half = do {
            my $q = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_ui($q, 1, 2);
            $q;
        };

        Math::GMPq::Rmpq_add($n, $n, $half);
        Math::GMPz::Rmpz_set_q($z, $n);

        if (Math::GMPz::Rmpz_odd_p($z) and Math::GMPq::Rmpq_integer_p($n)) {
            Math::GMPz::Rmpz_sub_ui($z, $z, 1);
        }

        Math::GMPq::Rmpq_set_z($n, $z);

        if ($nth < 0) {
            Math::GMPq::Rmpq_mul($n, $n, $p);
        }
        else {
            Math::GMPq::Rmpq_div($n, $n, $p);
        }

        if ($sgn < 0) {
            Math::GMPq::Rmpq_neg($n, $n);
        }

        bless \$n, __PACKAGE__;
    }

    *roundf = \&round;

    sub to {
        my ($from, $to, $step) = @_;
        Sidef::Types::Range::RangeNumber->new($from, $to, $step // ONE,);
    }

    *upto = \&to;

    sub downto {
        my ($from, $to, $step) = @_;
        Sidef::Types::Range::RangeNumber->new($from, $to, defined($step) ? $step->neg : MONE);
    }

    sub xto {
        my ($from, $to, $step) = @_;

        $to =
          defined($step)
          ? $to->sub($step)
          : $to->dec;

        Sidef::Types::Range::RangeNumber->new($from, $to, $step // ONE);
    }

    *xupto = \&xto;

    sub xdownto {
        my ($from, $to, $step) = @_;

        $from =
          defined($step)
          ? $from->sub($step)
          : $from->dec;

        Sidef::Types::Range::RangeNumber->new($from, $to, defined($step) ? $step->neg : MONE);
    }

    sub range {
        my ($from, $to, $step) = @_;

        defined($to)
          ? $from->to($to, $step)
          : (ZERO)->to($from->dec);
    }

    sub rand {
        my ($x, $y) = @_;

        state $state = Math::MPFR::Rmpfr_randinit_mt();
        state $seed = Math::MPFR::Rmpfr_randseed_ui($state, scalar srand());

        my $rand = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_urandom($rand, $state, $ROUND);

        my $q = Math::GMPq::Rmpq_init();
        Math::MPFR::Rmpfr_get_q($q, $rand);

        if (defined $y) {

            if (   ref($y) eq 'Sidef::Types::Number::Inf'
                or ref($y) eq 'Sidef::Types::Number::Ninf'
                or ref($y) eq 'Sidef::Types::Number::Nan') {
                return $y;
            }

            _valid(\$y);

            my $diff = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_sub($diff, $$y, $$x);
            Math::GMPq::Rmpq_mul($q, $q, $diff);
            Math::GMPq::Rmpq_add($q, $q, $$x);
        }
        else {
            Math::GMPq::Rmpq_mul($q, $q, $$x);
        }

        bless \$q, __PACKAGE__;
    }

    sub irand {
        my ($x, $y) = @_;

        state $state = Math::GMPz::zgmp_randinit_mt();
        state $seed = Math::GMPz::zgmp_randseed_ui($state, scalar srand());

        $x = _big2mpz($x);

        if (defined($y)) {

            if (   ref($y) eq 'Sidef::Types::Number::Inf'
                or ref($y) eq 'Sidef::Types::Number::Ninf'
                or ref($y) eq 'Sidef::Types::Number::Nan') {
                return $y;
            }

            _valid(\$y);

            my $rand = _big2mpz($y);
            my $cmp = Math::GMPz::Rmpz_cmp($rand, $x);

            if ($cmp == 0) {
                return _mpz2big($rand);
            }
            elsif ($cmp < 0) {
                ($x, $rand) = ($rand, $x);
            }

            Math::GMPz::Rmpz_sub($rand, $rand, $x);
            Math::GMPz::Rmpz_urandomm($rand, $state, $rand, 1);
            Math::GMPz::Rmpz_add($rand, $rand, $x);

            _mpz2big($rand);
        }
        else {
            my $sgn = Math::GMPz::Rmpz_sgn($x);
            Math::GMPz::Rmpz_urandomm($x, $state, $x, 1);
            Math::GMPz::Rmpz_neg($x, $x) if $sgn < 0;
            _mpz2big($x);
        }
    }

    sub of {
        my ($x, $obj) = @_;

        if (ref($obj) eq 'Sidef::Types::Block::Block') {

            my @array;
            my $num = _big2mpz($x);

            for (my $i = Math::GMPz::Rmpz_init_set_ui(1) ;
                 Math::GMPz::Rmpz_cmp($i, $num) <= 0 ;
                 Math::GMPz::Rmpz_add_ui($i, $i, 1)) {
                my $n = Math::GMPq::Rmpq_init();
                Math::GMPq::Rmpq_set_z($n, $i);
                push @array, $obj->run(bless(\$n, __PACKAGE__));
            }

            return Sidef::Types::Array::Array->new(\@array);
        }

        Sidef::Types::Array::Array->new([($obj) x Math::GMPq::Rmpq_get_d($$x)]);
    }

    sub defs {
        my ($x, $block) = @_;

        my $j   = 0;
        my $end = Math::GMPq::Rmpq_get_d($$x);

        my @items;
        for (my $i = Math::GMPz::Rmpz_init_set_ui(1) ; ; Math::GMPz::Rmpz_add_ui($i, $i, 1)) {
            my $n = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_z($n, $i);
            push @items, $block->run(bless(\$n, __PACKAGE__)) // next;
            last if ++$j == $end;
        }

        Sidef::Types::Array::Array->new(\@items);
    }

    sub times {
        my ($num, $block) = @_;

        $num = _big2mpz($num);

        for (my $i = Math::GMPz::Rmpz_init_set_ui(1) ;
             Math::GMPz::Rmpz_cmp($i, $num) <= 0 ; Math::GMPz::Rmpz_add_ui($i, $i, 1)) {
            my $n = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_z($n, $i);
            $block->run(bless(\$n, __PACKAGE__));
        }

        $block;
    }

    sub itimes {
        my ($num, $block) = @_;

        $num = _big2mpz($num);

        for (my $i = Math::GMPz::Rmpz_init_set_ui(0) ; Math::GMPz::Rmpz_cmp($i, $num) < 0 ; Math::GMPz::Rmpz_add_ui($i, $i, 1))
        {
            my $n = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_z($n, $i);
            $block->run(bless(\$n, __PACKAGE__));
        }

        $block;
    }

    sub commify {
        my ($self) = @_;

        my $n = "$self";

        my $x   = $n;
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

    #
    ## Conversions
    #

    sub rad2deg {
        my ($x) = @_;
        state $f = do {
            my $fr = Math::MPFR::Rmpfr_init2($PREC);
            my $pi = Math::MPFR::Rmpfr_init2($PREC);
            Math::MPFR::Rmpfr_const_pi($pi, $ROUND);
            Math::MPFR::Rmpfr_ui_div($fr, 180, $pi, $ROUND);
            _mpfr2big($fr);
        };
        $f->mul($x);
    }

    sub deg2rad {
        my ($x) = @_;
        state $f = do {
            my $fr = Math::MPFR::Rmpfr_init2($PREC);
            my $pi = Math::MPFR::Rmpfr_init2($PREC);
            Math::MPFR::Rmpfr_const_pi($pi, $ROUND);
            Math::MPFR::Rmpfr_div_ui($fr, $pi, 180, $ROUND);
            _mpfr2big($fr);
        };
        $f->mul($x);
    }

    sub rad2grad {
        my ($x) = @_;
        state $factor = do {
            my $fr = Math::MPFR::Rmpfr_init2($PREC);
            my $pi = Math::MPFR::Rmpfr_init2($PREC);
            Math::MPFR::Rmpfr_const_pi($pi, $ROUND);
            Math::MPFR::Rmpfr_ui_div($fr, 200, $pi, $ROUND);
            _mpfr2big($fr);
        };
        $factor->mul($x);
    }

    sub grad2rad {
        my ($x) = @_;
        state $factor = do {
            my $fr = Math::MPFR::Rmpfr_init2($PREC);
            my $pi = Math::MPFR::Rmpfr_init2($PREC);
            Math::MPFR::Rmpfr_const_pi($pi, $ROUND);
            Math::MPFR::Rmpfr_div_ui($fr, $pi, 200, $ROUND);
            _mpfr2big($fr);
        };
        $factor->mul($x);
    }

    sub grad2deg {
        my ($x) = @_;
        state $factor = do {
            my $q = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_ui($q, 9, 10);
            $q;
        };
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_mul($r, $factor, $$x);
        bless \$r, __PACKAGE__;
    }

    sub deg2grad {
        my ($x) = @_;
        state $factor = do {
            my $q = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_ui($q, 10, 9);
            $q;
        };
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_mul($r, $factor, $$x);
        bless \$r, __PACKAGE__;
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
        *{__PACKAGE__ . '::' . '..'}  = \&to;
        *{__PACKAGE__ . '::' . '..^'} = \&xto;
        *{__PACKAGE__ . '::' . '^..'} = \&xdownto;
        *{__PACKAGE__ . '::' . '!'}   = \&factorial;
        *{__PACKAGE__ . '::' . '%%'}  = \&is_div;
        *{__PACKAGE__ . '::' . '>>'}  = \&shift_right;
        *{__PACKAGE__ . '::' . '<<'}  = \&shift_left;
        *{__PACKAGE__ . '::' . '~'}   = \&not;
        *{__PACKAGE__ . '::' . ':'}   = \&complex;
        *{__PACKAGE__ . '::' . '//'}  = \&idiv;
        *{__PACKAGE__ . '::' . 'γ'}  = \&Y;
        *{__PACKAGE__ . '::' . 'Γ'}  = \&gamma;
        *{__PACKAGE__ . '::' . 'Ψ'}  = \&digamma;
    }
}

1
