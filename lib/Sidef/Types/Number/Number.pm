package Sidef::Types::Number::Number {

    use utf8;
    use 5.016;

    use Math::GMPq qw();
    use Math::GMPz qw();
    use Math::MPFR qw();
    use Math::Prime::Util::GMP qw();

    our $ROUND = Math::MPFR::MPFR_RNDN();
    our $PREC  = 200;

    Math::GMPq::Rmpq_set_ui((state $ONE  = Math::GMPq::Rmpq_init_nobless()), 1, 1);
    Math::GMPq::Rmpq_set_ui((state $ZERO = Math::GMPq::Rmpq_init_nobless()), 0, 1);
    Math::GMPq::Rmpq_set_si((state $MONE = Math::GMPq::Rmpq_init_nobless()), -1, 1);

    use constant {
        ONE  => bless(\$ONE,  __PACKAGE__),
        ZERO => bless(\$ZERO, __PACKAGE__),
        MONE => bless(\$MONE, __PACKAGE__),

        MAX_UI => Math::GMPq::_ulong_max(),
        MIN_SI => Math::GMPq::_long_min(),
                 };

    use parent qw(
      Sidef::Object::Object
      Sidef::Convert::Convert
      );

    use overload
      q{bool} => sub { !!Math::GMPq::Rmpq_sgn(${$_[0]}) },
      q{0+}   => \&get_value,
      q{""}   => \&_big2str;

    use Sidef::Types::Bool::Bool;

    my @cache = (ZERO, ONE);

    sub _new {
        bless(\$_[0], __PACKAGE__);
    }

    sub _deparse {
        my $x = ${$_[0]};

        if (    Math::GMPq::Rmpq_integer_p($x)
            and Math::GMPq::Rmpq_cmp_ui($x, MAX_UI, 1) <= 0
            and Math::GMPq::Rmpq_cmp_si($x, MIN_SI, 1) >= 0) {
            (Math::GMPq::Rmpq_sgn($x), Math::GMPq::Rmpq_get_str($x, 10));
        }
        else {
            (2, Math::GMPq::Rmpq_get_str($x, 10));
        }
    }

    sub _get_frac {
        Math::GMPq::Rmpq_get_str(${$_[0]}, 10);
    }

    sub _get_double {
        Math::GMPq::Rmpq_get_d(${$_[0]});
    }

    sub _set_uint {
        $_[1] <= 8192
          ? do {
            exists($cache[$_[1]]) and return $cache[$_[1]];
            Math::GMPq::Rmpq_set_ui((my $r = Math::GMPq::Rmpq_init_nobless()), $_[1], 1);
            ($cache[$_[1]] = bless(\$r, __PACKAGE__));
          }
          : do {
            Math::GMPq::Rmpq_set_ui((my $r = Math::GMPq::Rmpq_init()), $_[1], 1);
            bless(\$r, __PACKAGE__);
          };
    }

    sub _set_int {
        $_[1] == -1 && return MONE;
        $_[1] >= 0  && goto &_set_uint;
        Math::GMPq::Rmpq_set_si((my $r = Math::GMPq::Rmpq_init()), $_[1], 1);
        bless(\$r, __PACKAGE__);
    }

    sub _set_str {
        Math::GMPq::Rmpq_set_str((my $r = Math::GMPq::Rmpq_init()), $_[1], 10);
        bless \$r, __PACKAGE__;
    }

    sub new {
        my (undef, $num, $base) = @_;

        ref($num) eq 'Math::GMPq' ? bless(\$num, __PACKAGE__)
          : (!defined($base) and ref($num) eq __PACKAGE__) ? $num
          : do {

            $num = "$num" || return ZERO;

            if (!defined $base) {
                my $lc = lc($num);
                if ($lc eq 'inf' or $lc eq '+inf') {
                    return inf();
                }
                elsif ($lc eq '-inf') {
                    return ninf();
                }
                elsif ($lc eq 'nan') {
                    return nan();
                }
                $base = 10;
            }
            else {
                $base = CORE::int($base);
            }

            # True when the number is a fraction
            my $is_frac = index($num, '/') != -1;

            my $rat = (!$is_frac and $base == 10 and $num =~ tr/Ee.//)
              ? do {
                my $r = _str2rat($num =~ tr/_//dr);
                $is_frac = index($r, '/') != -1;
                $r;
              }
              : ($num =~ tr/_+//dr);

            if ($is_frac and ($base == 10 ? ($rat !~ m{^\s*[-+]?[0-9]+(?>\s*/\s*[-+]?[1-9]+[0-9]*)?\s*\z}) : 1)) {
                my ($num, $den) = split(/\//, $rat, 2);
                return ($den eq '' ? nan() : __PACKAGE__->new($num, $base)->div(__PACKAGE__->new($den, $base)));
            }

            my $r = Math::GMPq::Rmpq_init();

            # Set the string
            eval { Math::GMPq::Rmpq_set_str($r, $rat, $base); 1 } // return nan();

            # Canonicalize the fraction
            Math::GMPq::Rmpq_canonicalize($r) if $is_frac;

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

        $PREC = CORE::int($PREC) if ref($PREC);

        my $r = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_q($r, ${$_[0]}, $ROUND);
        $r;
    }

    sub _big2istr {
        my $q = ${$_[0]};
        Math::GMPq::Rmpq_integer_p($q) ? Math::GMPq::Rmpq_get_str($q, 10) : do {
            Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $q);
            Math::GMPz::Rmpz_get_str($z, 10);
        };
    }

    ################ CACHE FOR TEMPORARY MPZ OBJECTS ################
    ## Unfortunately, it turned out to be slightly slower in general.
#<<<
    #~ {
        #~ my $limit = 5;
        #~ my $ptr   = 0;

        #~ my @tmp_mpz = ((map { scalar Math::GMPz::Rmpz_init() } 1 .. $limit-1), undef);

        #~ sub _big2mpz {
            #~ my $mpz;

            #~ do {
                #~ if (not defined ($mpz = $tmp_mpz[$ptr++])) {
                    #~ #say "big2mpz -- ",  (caller(1))[3];
                    #~ $ptr = 0;
                    #~ $mpz = Math::GMPz::Rmpz_init();
                #~ }
            #~ } while (&Internals::SvREFCNT($mpz) > 1);

            #~ $ptr = 0 if ($ptr == $limit - 1);
            #~ Math::GMPz::Rmpz_set_q($mpz, ${$_[0]});
            #~ $mpz;
        #~ }
    #~ }
#>>>
    #################################################################

    sub _big2mpz {
        Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), ${$_[0]});
        $z;
    }

    sub _mpfr2big {

        Math::MPFR::Rmpfr_number_p($_[0]) || do {
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
        };

        Math::MPFR::Rmpfr_get_q((my $r = Math::GMPq::Rmpq_init()), $_[0]);
        bless \$r, __PACKAGE__;
    }

    sub _mpz2big {
        Math::GMPq::Rmpq_set_z((my $r = Math::GMPq::Rmpq_init()), $_[0]);
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
                Math::MPFR::Rmpfr_set_str((my $mpfr = Math::MPFR::Rmpfr_init2($PREC)), "$sign$str", 10, $ROUND);
                Math::MPFR::Rmpfr_get_q((my $mpq = Math::GMPq::Rmpq_init()), $mpfr);
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
        my $x = ${$_[0]};
        Math::GMPq::Rmpq_integer_p($x)
          ? Math::GMPq::Rmpq_get_str($x, 10)
          : do {
            $PREC = CORE::int($PREC) if ref($PREC);

            my $prec = CORE::int($PREC / 4);
            my $sgn  = Math::GMPq::Rmpq_sgn($x);

            Math::GMPq::Rmpq_set((my $n = Math::GMPq::Rmpq_init()), $x);
            Math::GMPq::Rmpq_abs($n, $n) if $sgn < 0;

            Math::GMPq::Rmpq_set_str((my $p = Math::GMPq::Rmpq_init()), '1' . ('0' x CORE::abs($prec)), 10);

            if ($prec < 0) {
                Math::GMPq::Rmpq_div($n, $n, $p);
            }
            else {
                Math::GMPq::Rmpq_mul($n, $n, $p);
            }

            state $half = do {
                Math::GMPq::Rmpq_set_ui((my $q = Math::GMPq::Rmpq_init_nobless()), 1, 2);
                $q;
            };

            Math::GMPq::Rmpq_add($n, $n, $half);
            Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $n);

            # Too much rounding... Give up and return an MPFR stringified number.
            !Math::GMPz::Rmpz_sgn($z) && $PREC >= 2 && do {
                Math::MPFR::Rmpfr_set_q((my $mpfr = Math::MPFR::Rmpfr_init2($PREC)), $x, $ROUND);
                return Math::MPFR::Rmpfr_get_str($mpfr, 10, $prec, $ROUND);
            };

            if (Math::GMPz::Rmpz_odd_p($z) and Math::GMPq::Rmpq_integer_p($n)) {
                Math::GMPz::Rmpz_sub_ui($z, $z, 1);
            }

            Math::GMPq::Rmpq_set_z($n, $z);

            if ($prec < 0) {
                Math::GMPq::Rmpq_mul($n, $n, $p);
            }
            else {
                Math::GMPq::Rmpq_div($n, $n, $p);
            }

            Math::GMPq::Rmpq_numref((my $num = Math::GMPz::Rmpz_init()), $n);
            Math::GMPq::Rmpq_denref((my $den = Math::GMPz::Rmpz_init()), $n);

            my @r;
            my $c = 0;

            while (1) {

                Math::GMPz::Rmpz_div($z, $num, $den);
                push @r, Math::GMPz::Rmpz_get_str($z, 10);

                Math::GMPz::Rmpz_mul($z, $z, $den);
                last if Math::GMPz::Rmpz_divisible_p($num, $den);
                Math::GMPz::Rmpz_sub($num, $num, $z);

                my $s = -1;
                while (Math::GMPz::Rmpz_cmp($den, $num) > 0) {
                    last if !Math::GMPz::Rmpz_sgn($num);
                    Math::GMPz::Rmpz_mul_ui($num, $num, 10);
                    ++$s;
                }

                push(@r, '0' x $s) if ($s > 0);
            }

            ($sgn < 0 ? "-" : '') . shift(@r) . (('.' . join('', @r)) =~ s/0+\z//r =~ s/\.\z//r);
          }
    }

    sub base {
        my ($x, $y) = @_;
        _valid(\$y);

        $y = CORE::int(Math::GMPq::Rmpq_get_d($$y));

        if ($y < 2 or $y > 36) {
            die "[ERROR] base must be between 2 and 36, got $y\n";
        }

        Sidef::Types::String::String->new(Math::GMPq::Rmpq_get_str($$x, $y));
    }

    *in_base = \&base;

    #
    ## Constants
    #

    sub pi {
        Math::MPFR::Rmpfr_const_pi((my $pi = Math::MPFR::Rmpfr_init2($PREC)), $ROUND);
        _mpfr2big($pi);
    }

    sub tau {
        Math::MPFR::Rmpfr_const_pi((my $tau = Math::MPFR::Rmpfr_init2($PREC)), $ROUND);
        Math::MPFR::Rmpfr_mul_ui($tau, $tau, 2, $ROUND);
        _mpfr2big($tau);
    }

    sub ln2 {
        Math::MPFR::Rmpfr_const_log2((my $ln2 = Math::MPFR::Rmpfr_init2($PREC)), $ROUND);
        _mpfr2big($ln2);
    }

    sub Y {
        Math::MPFR::Rmpfr_const_euler((my $euler = Math::MPFR::Rmpfr_init2($PREC)), $ROUND);
        _mpfr2big($euler);
    }

    sub G {
        Math::MPFR::Rmpfr_const_catalan((my $catalan = Math::MPFR::Rmpfr_init2($PREC)), $ROUND);
        _mpfr2big($catalan);
    }

    sub e {
        state $one_f = (Math::MPFR::Rmpfr_init_set_ui_nobless(1, $ROUND))[0];
        Math::MPFR::Rmpfr_exp((my $e = Math::MPFR::Rmpfr_init2($PREC)), $one_f, $ROUND);
        _mpfr2big($e);
    }

    sub phi {
        state $five4_f = (Math::MPFR::Rmpfr_init_set_str_nobless("1.25", 10, $ROUND))[0];
        state $half_f  = (Math::MPFR::Rmpfr_init_set_str_nobless("0.5",  10, $ROUND))[0];

        Math::MPFR::Rmpfr_sqrt((my $phi = Math::MPFR::Rmpfr_init2($PREC)), $five4_f, $ROUND);
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
        Math::GMPq::Rmpq_add((my $r = Math::GMPq::Rmpq_init()), $$x, $$y);
        bless \$r, __PACKAGE__;
    }

    sub iadd {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $y;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_add($x, $x, _big2mpz($y));
        _mpz2big($x);
    }

    sub fadd {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $y;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);
        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_add($x, $x, _big2mpfr($y), $ROUND);
        _mpfr2big($x);
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
        Math::GMPq::Rmpq_sub((my $r = Math::GMPq::Rmpq_init()), $$x, $$y);
        bless \$r, __PACKAGE__;
    }

    sub isub {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $y->neg;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_sub($x, $x, _big2mpz($y));
        _mpz2big($x);
    }

    sub fsub {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $y->neg;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);
        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_sub($x, $x, _big2mpfr($y), $ROUND);
        _mpfr2big($x);
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
        Math::GMPq::Rmpq_mul((my $r = Math::GMPq::Rmpq_init()), $$x, $$y);
        bless \$r, __PACKAGE__;
    }

    sub imul {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            my $sign = Math::GMPq::Rmpq_sgn($$x);
            return ($sign < 0 ? $y->neg : $sign > 0 ? $y : nan());
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_mul($x, $x, _big2mpz($y));
        _mpz2big($x);
    }

    sub fmul {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            my $sign = Math::GMPq::Rmpq_sgn($$x);
            return ($sign < 0 ? $y->neg : $sign > 0 ? $y : nan());
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);
        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_mul($x, $x, _big2mpfr($y), $ROUND);
        _mpfr2big($x);
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

        $x = $$x;
        $y = $$y;

        Math::GMPq::Rmpq_sgn($y) || do {
            my $sign = Math::GMPq::Rmpq_sgn($x);
            return (!$sign ? nan() : $sign > 0 ? inf() : ninf());
        };

        Math::GMPq::Rmpq_div((my $r = Math::GMPq::Rmpq_init()), $x, $y);
        bless \$r, __PACKAGE__;
    }

    sub fdiv {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (ZERO);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);
        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_div($x, $x, _big2mpfr($y), $ROUND);
        _mpfr2big($x);
    }

    sub idiv {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (ZERO);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        $x = _big2mpz($x);
        $y = _big2mpz($y);

        Math::GMPz::Rmpz_sgn($y) || do {
            my $sign = Math::GMPz::Rmpz_sgn($x);
            return (!$sign ? nan() : $sign > 0 ? inf() : ninf());
        };

        Math::GMPz::Rmpz_div($x, $x, $y);
        _mpz2big($x);
    }

    sub neg {
        my ($x) = @_;
        Math::GMPq::Rmpq_neg((my $r = Math::GMPq::Rmpq_init()), $$x);
        bless \$r, __PACKAGE__;
    }

    *negative = \&neg;

    sub abs {
        my $q = ${$_[0]};
        Math::GMPq::Rmpq_sgn($q) >= 0 and return ($_[0]);
        Math::GMPq::Rmpq_abs((my $r = Math::GMPq::Rmpq_init()), $q);
        bless \$r, __PACKAGE__;
    }

    *pos      = \&abs;
    *positive = \&abs;

    sub inv {
        my ($x) = @_;
        Math::GMPq::Rmpq_sgn($$x) || return inf();    # Return Inf when x is zero
        Math::GMPq::Rmpq_inv((my $r = Math::GMPq::Rmpq_init()), $$x);
        bless \$r, __PACKAGE__;
    }

    sub sqrt {
        my ($x) = @_;

        # Return a complex number for x < 0
        Math::GMPq::Rmpq_sgn($$x) < 0
          and return Sidef::Types::Number::Complex->new($x)->sqrt;

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_sqrt($x, $x, $ROUND);
        _mpfr2big($x);
    }

    sub isqrt {
        my ($x) = @_;
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_sgn($x) < 0 and return nan();
        Math::GMPz::Rmpz_sqrt($x, $x);
        _mpz2big($x);
    }

    sub isqrtrem {
        my ($x) = @_;
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_sgn($x) < 0 and return ((nan()) x 2);
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_sqrtrem($x, $r, $x);
        (_mpz2big($x), _mpz2big($r));
    }

    sub irootrem {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            my $root = $x->iroot($y);
            return ($root, $x->isub($root->ipow($y)));
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return ((nan()) x 2);
        }

        _valid(\$y);
        $x = _big2mpz($x);
        my $root = CORE::int(Math::GMPq::Rmpq_get_d($$y));

        if ($root == 0) {
            Math::GMPz::Rmpz_sgn($x) || return (ZERO, MONE);    # 0^Inf = 0
            Math::GMPz::Rmpz_cmpabs_ui($x, 1) == 0 and return (ONE, _mpz2big($x)->dec);    # 1^Inf = 1 ; (-1)^Inf = 1
            return (inf(), _mpz2big($x)->dec);
        }
        elsif ($root < 0) {
            my $sign = Math::GMPz::Rmpz_sgn($x) || return (inf(), ZERO);                   # 1 / 0^k = Inf
            Math::GMPz::Rmpz_cmp_ui($x, 1) == 0 and return (ONE, ZERO);                    # 1 / 1^k = 1
            return ($sign < 0 ? (nan(), nan()) : (ZERO, ninf()));
        }
        elsif ($root % 2 == 0 and Math::GMPz::Rmpz_sgn($x) < 0) {
            return (nan(), nan());
        }

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_rootrem($x, $r, $x, $root);
        (_mpz2big($x), _mpz2big($r));
    }

    sub cbrt {
        my ($x) = @_;

        # Return a complex number for x < 0
        Math::GMPq::Rmpq_sgn($$x) < 0
          and return Sidef::Types::Number::Complex->new($x)->cbrt;

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_cbrt($x, $x, $ROUND);
        _mpfr2big($x);
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
        $x->pow($y->inv);
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

        $x = _big2mpz($x);

        my $root = CORE::int(Math::GMPq::Rmpq_get_d($$y));

        if ($root == 0) {
            Math::GMPz::Rmpz_sgn($x) || return ZERO;    # 0^Inf = 0
            Math::GMPz::Rmpz_cmpabs_ui($x, 1) == 0 and return ONE;    # 1^Inf = 1 ; (-1)^Inf = 1
            return inf();
        }
        elsif ($root < 0) {
            my $sign = Math::GMPz::Rmpz_sgn($x) || return inf();      # 1 / 0^k = Inf
            Math::GMPz::Rmpz_cmp_ui($x, 1) == 0 and return ONE;       # 1 / 1^k = 1
            return $sign < 0 ? nan() : ZERO;
        }
        elsif ($root % 2 == 0 and Math::GMPz::Rmpz_sgn($x) < 0) {
            return nan();
        }

        Math::GMPz::Rmpz_root($x, $x, $root);
        _mpz2big($x);
    }

    sub sqr {
        my ($x) = @_;
        Math::GMPq::Rmpq_mul((my $r = Math::GMPq::Rmpq_init()), $$x, $$x);
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

        if (Math::GMPq::Rmpq_integer_p($$y)) {

            my $q   = Math::GMPq::Rmpq_init();
            my $pow = Math::GMPq::Rmpq_get_d($$y);

            if (Math::GMPq::Rmpq_integer_p($$x)) {
                my $z = Math::GMPz::Rmpz_init_set($$x);
                Math::GMPz::Rmpz_pow_ui($z, $z, CORE::abs($pow));
                Math::GMPq::Rmpq_set_z($q, $z);

                if ($pow < 0) {
                    Math::GMPq::Rmpq_sgn($q) || return inf();
                    Math::GMPq::Rmpq_inv($q, $q);
                }
            }
            else {
                Math::GMPq::Rmpq_numref((my $z = Math::GMPz::Rmpz_init()), $$x);
                Math::GMPz::Rmpz_pow_ui($z, $z, CORE::abs($pow));

                Math::GMPq::Rmpq_set_num($q, $z);

                Math::GMPq::Rmpq_denref($z, $$x);
                Math::GMPz::Rmpz_pow_ui($z, $z, CORE::abs($pow));

                Math::GMPq::Rmpq_set_den($q, $z);

                Math::GMPq::Rmpq_inv($q, $q) if $pow < 0;
            }

            return bless \$q, __PACKAGE__;
        }
        elsif (Math::GMPq::Rmpq_sgn($$x) < 0) {
            return Sidef::Types::Number::Complex->new($x)->pow($y);
        }

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_pow($x, $x, _big2mpfr($y), $ROUND);
        _mpfr2big($x);
    }

    sub fpow {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_pow($x, $x, _big2mpfr($y), $ROUND);
        _mpfr2big($x);
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

        state $ONE_Z = Math::GMPz::Rmpz_init_set_ui_nobless(1);
        my $pow = CORE::int(Math::GMPq::Rmpq_get_d($$y));

        $x = _big2mpz($x);
        Math::GMPz::Rmpz_pow_ui($x, $x, CORE::abs($pow));

        if ($pow < 0) {
            return inf() if !Math::GMPz::Rmpz_sgn($x);
            Math::GMPz::Rmpz_tdiv_q($x, $ONE_Z, $x);
        }

        _mpz2big($x);
    }

    sub log {
        my ($x, $y) = @_;

        Math::GMPq::Rmpq_sgn($$x) < 0
          and return Sidef::Types::Number::Complex->new($x)->log($y);

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_log($x, $x, $ROUND);

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
            Math::MPFR::Rmpfr_div($x, $x, $baseln, $ROUND);
        }

        _mpfr2big($x);
    }

    sub ln {
        my ($x) = @_;

        Math::GMPq::Rmpq_sgn($$x) < 0
          and return Sidef::Types::Number::Complex->new($x)->ln;

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_log($x, $x, $ROUND);
        _mpfr2big($x);
    }

    sub log2 {
        my ($x) = @_;

        Math::GMPq::Rmpq_sgn($$x) < 0
          and return Sidef::Types::Number::Complex->new($x)->log2;

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_log2($x, $x, $ROUND);
        _mpfr2big($x);
    }

    sub log10 {
        my ($x) = @_;

        Math::GMPq::Rmpq_sgn($$x) < 0
          and return Sidef::Types::Number::Complex->new($x)->log10;

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_log10($x, $x, $ROUND);
        _mpfr2big($x);
    }

    sub lgrt {
        my ($x) = @_;

        my $sgn = Math::GMPq::Rmpq_sgn($$x);

        $sgn == 0 and return ninf();
        Math::GMPq::Rmpq_cmp_ui($$x, 7, 10) < 0 and return Sidef::Types::Number::Complex->new($x)->lgrt;

        my $d = _big2mpfr($x);
        Math::MPFR::Rmpfr_log($d, $d, $ROUND);

        $PREC = CORE::int($PREC);
        Math::MPFR::Rmpfr_ui_pow_ui((my $p = Math::MPFR::Rmpfr_init2($PREC)), 10, CORE::int($PREC / 4), $ROUND);
        Math::MPFR::Rmpfr_ui_div($p, 1, $p, $ROUND);

        Math::MPFR::Rmpfr_set_ui(($x = Math::MPFR::Rmpfr_init2($PREC)), 1, $ROUND);
        Math::MPFR::Rmpfr_set_ui((my $y = Math::MPFR::Rmpfr_init2($PREC)), 0, $ROUND);

        my $tmp = Math::MPFR::Rmpfr_init2($PREC);

        my $count = 0;
        while (1) {
            Math::MPFR::Rmpfr_sub($tmp, $x, $y, $ROUND);
            Math::MPFR::Rmpfr_cmpabs($tmp, $p) <= 0 and last;

            Math::MPFR::Rmpfr_set($y, $x, $ROUND);

            Math::MPFR::Rmpfr_log($tmp, $x, $ROUND);
            Math::MPFR::Rmpfr_add_ui($tmp, $tmp, 1, $ROUND);

            Math::MPFR::Rmpfr_add($x, $x, $d, $ROUND);
            Math::MPFR::Rmpfr_div($x, $x, $tmp, $ROUND);
            last if ++$count > $PREC;
        }

        _mpfr2big($x);
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

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_asin($x, $x, $ROUND);
        _mpfr2big($x);
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

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_acos($x, $x, $ROUND);
        _mpfr2big($x);
    }

    sub cosh {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_cosh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub acosh {
        my ($x) = @_;

        # Return a complex number for x < 1
        if (Math::GMPq::Rmpq_cmp_ui($$x, 1, 1) < 0) {
            return Sidef::Types::Number::Complex->new($x)->acosh;
        }

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_acosh($x, $x, $ROUND);
        _mpfr2big($x);
    }

    sub tan {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_tan($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub atan {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_atan($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub tanh {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_tanh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub atanh {
        my ($x) = @_;

        # Return a complex number for x <= -1 or x >= 1
        if (Math::GMPq::Rmpq_cmp_ui($$x, 1, 1) >= 0 or Math::GMPq::Rmpq_cmp_si($$x, -1, 1) <= 0) {
            return Sidef::Types::Number::Complex->new($x)->atanh;
        }

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_atanh($x, $x, $ROUND);
        _mpfr2big($x);
    }

    sub sec {
        my $r = _big2mpfr($_[0]);
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

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_ui_div($x, 1, $x, $ROUND);
        Math::MPFR::Rmpfr_acos($x, $x, $ROUND);
        _mpfr2big($x);
    }

    sub sech {
        my $r = _big2mpfr($_[0]);
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

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_ui_div($x, 1, $x, $ROUND);
        Math::MPFR::Rmpfr_acosh($x, $x, $ROUND);
        _mpfr2big($x);
    }

    sub csc {
        my $r = _big2mpfr($_[0]);
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

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_ui_div($x, 1, $x, $ROUND);
        Math::MPFR::Rmpfr_asin($x, $x, $ROUND);
        _mpfr2big($x);
    }

    sub csch {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_csch($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## acsch(x) = asinh(1/x)
    #
    sub acsch {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_ui_div($r, 1, $r, $ROUND);
        Math::MPFR::Rmpfr_asinh($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub cot {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_cot($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## acot(x) = atan(1/x)
    #
    sub acot {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_ui_div($r, 1, $r, $ROUND);
        Math::MPFR::Rmpfr_atan($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub coth {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_coth($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## acoth(x) = atanh(1/x)
    #
    sub acoth {
        my ($x) = @_;

        # Return a complex number for x > -1 and x < 1
        if (Math::GMPq::Rmpq_cmp_ui($$x, 1, 1) < 0 and Math::GMPq::Rmpq_cmp_si($$x, -1, 1) > 0) {
            return Sidef::Types::Number::Complex->new($x)->acoth;
        }

        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_ui_div($x, 1, $x, $ROUND);
        Math::MPFR::Rmpfr_atanh($x, $x, $ROUND);
        _mpfr2big($x);
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
        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_atan2($x, $x, _big2mpfr($y), $ROUND);
        _mpfr2big($x);
    }

    #
    ## Special functions
    #

    sub agm {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_agm($x, $x, _big2mpfr($y), $ROUND);
        _mpfr2big($x);
    }

    sub hypot {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_hypot($x, $x, _big2mpfr($y), $ROUND);
        _mpfr2big($x);
    }

    sub gamma {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_gamma($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub lngamma {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_lngamma($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub lgamma {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_lgamma($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub digamma {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_digamma($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub eta {
        my $r = _big2mpfr($_[0]);

        # Special case for eta(1) = log(2)
        if (!Math::MPFR::Rmpfr_cmp_ui($r, 1)) {
            Math::MPFR::Rmpfr_add_ui($r, $r, 1, $ROUND);
            Math::MPFR::Rmpfr_log($r, $r, $ROUND);
            return _mpfr2big($r);
        }

        my $p = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set($p, $r, $ROUND);
        Math::MPFR::Rmpfr_ui_sub($p, 1, $p, $ROUND);
        Math::MPFR::Rmpfr_ui_pow($p, 2, $p, $ROUND);
        Math::MPFR::Rmpfr_ui_sub($p, 1, $p, $ROUND);

        Math::MPFR::Rmpfr_zeta($r, $r, $ROUND);
        Math::MPFR::Rmpfr_mul($r, $r, $p, $ROUND);

        _mpfr2big($r);
    }

    sub zeta {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_zeta($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub bernfrac {
        my ($n) = @_;

        $n = CORE::int(Math::GMPq::Rmpq_get_d($$n));

        $n == 0 and return ONE;
        $n > 1 and $n % 2 and return ZERO;    # Bn=0 for odd n>1
        $n < 0 and return nan();

        # Using bernfrac() from `Math::Prime::Util::GMP`
        my ($num, $den) = Math::Prime::Util::GMP::bernfrac($n);
        Math::GMPq::Rmpq_set_str((my $q = Math::GMPq::Rmpq_init()), "$num/$den", 10);
        bless \$q, __PACKAGE__;

        # Old-code for computing the nth-Bernoulli number internally.
#<<<
        #~ # Use a faster algorithm based on values of the Zeta function.
        #~ # B(n) = (-1)^(n/2 + 1) * zeta(n)*2*n! / (2*pi)^n
        #~ if ($n >= 50) {

            #~ my $prec = (
                #~ $n <= 156
                #~ ? CORE::int($n * CORE::log($n) + 1)
                #~ : CORE::int($n * CORE::log($n) / CORE::log(2) - 3 * $n)    # TODO: optimize for large n (>50_000)
            #~ );

            #~ my $f = Math::MPFR::Rmpfr_init2($prec);
            #~ Math::MPFR::Rmpfr_zeta_ui($f, $n, $ROUND);                     # f = zeta(n)

            #~ my $z = Math::GMPz::Rmpz_init();
            #~ Math::GMPz::Rmpz_fac_ui($z, $n);                               # z = n!
            #~ Math::GMPz::Rmpz_div_2exp($z, $z, $n - 1);                     # z = z / 2^(n-1)
            #~ Math::MPFR::Rmpfr_mul_z($f, $f, $z, $ROUND);                   # f = f*z

            #~ my $p = Math::MPFR::Rmpfr_init2($prec);
            #~ Math::MPFR::Rmpfr_const_pi($p, $ROUND);                        # p = PI
            #~ Math::MPFR::Rmpfr_pow_ui($p, $p, $n, $ROUND);                  # p = p^n
            #~ Math::MPFR::Rmpfr_div($f, $f, $p, $ROUND);                     # f = f/p

            #~ Math::GMPz::Rmpz_set_ui($z, 1);                                # z = 1
            #~ Math::GMPz::Rmpz_mul_2exp($z, $z, $n + 1);                     # z = 2^(n+1)
            #~ Math::GMPz::Rmpz_sub_ui($z, $z, 2);                            # z = z-2

            #~ Math::MPFR::Rmpfr_mul_z($f, $f, $z, $ROUND);                   # f = f*z
            #~ Math::MPFR::Rmpfr_round($f, $f);                               # f = [f]

            #~ my $q = Math::GMPq::Rmpq_init();
            #~ Math::MPFR::Rmpfr_get_q($q, $f);                               # q = f
            #~ Math::GMPq::Rmpq_set_den($q, $z);                              # q = q/z
            #~ Math::GMPq::Rmpq_canonicalize($q);                             # remove common factors

            #~ Math::GMPq::Rmpq_neg($q, $q) if $n % 4 == 0;                   # q = -q    (iff 4|n)
            #~ return bless \$q, __PACKAGE__;
        #~ }

        #~ my @D = (
                 #~ Math::GMPz::Rmpz_init_set_ui(0),
                 #~ Math::GMPz::Rmpz_init_set_ui(1),
                 #~ map { Math::GMPz::Rmpz_init_set_ui(0) } (1 .. $n / 2 - 1)
                #~ );

        #~ my ($h, $w) = (1, 1);
        #~ foreach my $i (0 .. $n - 1) {
            #~ if ($w ^= 1) {
                #~ Math::GMPz::Rmpz_add($D[$_], $D[$_], $D[$_ - 1]) for (1 .. $h - 1);
            #~ }
            #~ else {
                #~ $w = $h++;
                #~ Math::GMPz::Rmpz_add($D[$w], $D[$w], $D[$w + 1]) while --$w;
            #~ }
        #~ }

        #~ my $den = Math::GMPz::Rmpz_init_set_ui(1);
        #~ Math::GMPz::Rmpz_mul_2exp($den, $den, $n + 1);
        #~ Math::GMPz::Rmpz_sub_ui($den, $den, 2);
        #~ Math::GMPz::Rmpz_neg($den, $den) if $n % 4 == 0;

        #~ Math::GMPq::Rmpq_set_num((my $r = Math::GMPq::Rmpq_init()), $D[$h - 1]);
        #~ Math::GMPq::Rmpq_set_den($r, $den);
        #~ Math::GMPq::Rmpq_canonicalize($r);

        #~ bless \$r, __PACKAGE__;
#>>>
    }

    *bern      = \&bernfrac;
    *bernoulli = \&bernfrac;

    sub bernreal {
        my $n = CORE::int(Math::GMPq::Rmpq_get_d(${$_[0]}));

        # |B(n)| = zeta(n) * n! / 2^(n-1) / pi^n

        $n < 0  and return nan();
        $n == 0 and return ONE;
        $n == 1 and return do { state $x = __PACKAGE__->_set_str('1/2') };
        $n % 2 and return ZERO;    # Bn = 0 for odd n>1

        #local $PREC = CORE::int($n*CORE::log($n)+1);

        my $f = Math::MPFR::Rmpfr_init2($PREC);
        my $p = Math::MPFR::Rmpfr_init2($PREC);

        Math::MPFR::Rmpfr_zeta_ui($f, $n, $ROUND);    # f = zeta(n)
        Math::MPFR::Rmpfr_const_pi($p, $ROUND);       # p = PI
        Math::MPFR::Rmpfr_pow_ui($p, $p, $n, $ROUND); # p = p^n

        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_fac_ui($z, $n);              # z = n!
        Math::GMPz::Rmpz_div_2exp($z, $z, $n - 1);    # z = z / 2^(n-1)
        Math::MPFR::Rmpfr_mul_z($f, $f, $z, $ROUND);  # f = f * z

        Math::MPFR::Rmpfr_div($f, $f, $p, $ROUND);    # f = f/p
        Math::MPFR::Rmpfr_neg($f, $f, $ROUND) if $n % 4 == 0;

        _mpfr2big($f);
    }

    sub harmfrac {
        my ($n) = @_;

        my $ui = CORE::int(Math::GMPq::Rmpq_get_d($$n));

        $ui || return ZERO();
        $ui < 0 and return nan();

        # Using harmfrac() from Math::Prime::Util::GMP
        my ($num, $den) = Math::Prime::Util::GMP::harmfrac($n);
        Math::GMPq::Rmpq_set_str((my $q = Math::GMPq::Rmpq_init()), "$num/$den", 10);
        bless \$q, __PACKAGE__;

        # Old-code used for computing the nth-harmonic number internally.
#<<<
        #~ # Use binary splitting for large values of n. (by Fredrik Johansson)
        #~ # http://fredrik-j.blogspot.ro/2009/02/how-not-to-compute-harmonic-numbers.html
        #~ if ($ui > 7000) {

            #~ my $num = Math::GMPz::Rmpz_init_set_ui(1);

            #~ my $den = Math::GMPz::Rmpz_init();
            #~ Math::GMPz::Rmpz_set_q($den, $$n);
            #~ Math::GMPz::Rmpz_add_ui($den, $den, 1);

            #~ my $temp = Math::GMPz::Rmpz_init();

            #~ # Inspired by Dana Jacobsen's code from Math::Prime::Util::{PP,GMP}.
            #~ #   https://metacpan.org/pod/Math::Prime::Util::PP
            #~ #   https://metacpan.org/pod/Math::Prime::Util::GMP
            #~ sub {
                #~ my ($num, $den) = @_;
                #~ Math::GMPz::Rmpz_sub($temp, $den, $num);

                #~ if (Math::GMPz::Rmpz_cmp_ui($temp, 1) == 0) {
                    #~ Math::GMPz::Rmpz_set($den, $num);
                    #~ Math::GMPz::Rmpz_set_ui($num, 1);
                #~ }
                #~ elsif (Math::GMPz::Rmpz_cmp_ui($temp, 2) == 0) {
                    #~ Math::GMPz::Rmpz_set($den, $num);
                    #~ Math::GMPz::Rmpz_mul_2exp($num, $num, 1);
                    #~ Math::GMPz::Rmpz_add_ui($num, $num, 1);
                    #~ Math::GMPz::Rmpz_addmul($den, $den, $den);
                #~ }
                #~ else {
                    #~ Math::GMPz::Rmpz_add($temp, $num, $den);
                    #~ Math::GMPz::Rmpz_tdiv_q_2exp($temp, $temp, 1);
                    #~ my $q = Math::GMPz::Rmpz_init_set($temp);
                    #~ my $r = Math::GMPz::Rmpz_init_set($temp);
                    #~ __SUB__->($num, $q);
                    #~ __SUB__->($r,   $den);
                    #~ Math::GMPz::Rmpz_mul($num,  $num, $den);
                    #~ Math::GMPz::Rmpz_mul($temp, $q,   $r);
                    #~ Math::GMPz::Rmpz_add($num, $num, $temp);
                    #~ Math::GMPz::Rmpz_mul($den, $den, $q);
                #~ }
              #~ }
              #~ ->($num, $den);

            #~ my $q = Math::GMPq::Rmpq_init();
            #~ Math::GMPq::Rmpq_set_num($q, $num);
            #~ Math::GMPq::Rmpq_set_den($q, $den);
            #~ Math::GMPq::Rmpq_canonicalize($q);

            #~ return bless \$q, __PACKAGE__;
        #~ }

        #~ my $num = Math::GMPz::Rmpz_init_set_ui(1);
        #~ my $den = Math::GMPz::Rmpz_init_set_ui(1);

        #~ for (my $k = 2 ; $k <= $ui ; ++$k) {
            #~ Math::GMPz::Rmpz_mul_ui($num, $num, $k);    # num = num * k
            #~ Math::GMPz::Rmpz_add($num, $num, $den);     # num = num + den
            #~ Math::GMPz::Rmpz_mul_ui($den, $den, $k);    # den = den * k
        #~ }

        #~ my $r = Math::GMPq::Rmpq_init();
        #~ Math::GMPq::Rmpq_set_num($r, $num);
        #~ Math::GMPq::Rmpq_set_den($r, $den);
        #~ Math::GMPq::Rmpq_canonicalize($r);

        #~ bless \$r, __PACKAGE__;
#>>>
    }

    *harm     = \&harmfrac;
    *harmonic = \&harmfrac;

    sub harmreal {
        my ($n) = @_;

        $n = _big2mpfr($n);
        Math::MPFR::Rmpfr_add_ui($n, $n, 1, $ROUND);
        Math::MPFR::Rmpfr_digamma($n, $n, $ROUND);

        my $y = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_const_euler($y, $ROUND);
        Math::MPFR::Rmpfr_add($n, $n, $y, $ROUND);

        _mpfr2big($n);
    }

    sub erf {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_erf($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub erfc {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_erfc($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub eint {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_eint($r, $r, $ROUND);
        _mpfr2big($r);
    }

    *ei = \&eint;

    sub li {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_log($r, $r, $ROUND);
        Math::MPFR::Rmpfr_eint($r, $r, $ROUND);
        _mpfr2big($r);
    }

    sub li2 {
        my $r = _big2mpfr($_[0]);
        Math::MPFR::Rmpfr_li2($r, $r, $ROUND);
        _mpfr2big($r);
    }

    #
    ## Comparison and testing operations
    #

    sub eq {
        my ($x, $y) = @_;

        ref($y) ne __PACKAGE__
          and return Sidef::Types::Bool::Bool::FALSE;

        _valid(\$y);
        Math::GMPq::Rmpq_equal($$x, $$y)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub ne {
        my ($x, $y) = @_;

        ref($y) ne __PACKAGE__
          and return Sidef::Types::Bool::Bool::TRUE;

        _valid(\$y);
        Math::GMPq::Rmpq_equal($$x, $$y)
          ? (Sidef::Types::Bool::Bool::FALSE)
          : (Sidef::Types::Bool::Bool::TRUE);
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
        $x = Math::GMPq::Rmpq_cmp($$x, $$y);
        !$x ? (ZERO) : $x < 0 ? (MONE) : (ONE);
    }

    sub acmp {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = $$x;
        $y = $$y;

        if (Math::GMPq::Rmpq_sgn($x) < 0) {
            Math::GMPq::Rmpq_abs((my $r = Math::GMPq::Rmpq_init()), $x);
            $x = $r;
        }

        if (Math::GMPq::Rmpq_sgn($y) < 0) {
            Math::GMPq::Rmpq_abs((my $r = Math::GMPq::Rmpq_init()), $y);
            $y = $r;
        }

        $x = Math::GMPq::Rmpq_cmp($x, $y);
        !$x ? (ZERO) : $x < 0 ? (MONE) : (ONE);
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

        Math::GMPq::Rmpq_cmp($$x, $$y) > 0
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
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

        Math::GMPq::Rmpq_cmp($$x, $$y) >= 0
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
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

        Math::GMPq::Rmpq_cmp($$x, $$y) < 0
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
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

        Math::GMPq::Rmpq_cmp($$x, $$y) <= 0
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_zero {
        my ($x) = @_;
        (!Math::GMPq::Rmpq_sgn($$x))
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_one {
        my ($x) = @_;
        Math::GMPq::Rmpq_equal($$x, $ONE)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_mone {
        my ($x) = @_;
        Math::GMPq::Rmpq_equal($$x, $MONE)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_positive {
        my ($x) = @_;
        Math::GMPq::Rmpq_sgn($$x) > 0
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    *is_pos = \&is_positive;

    sub is_negative {
        my ($x) = @_;
        Math::GMPq::Rmpq_sgn($$x) < 0
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    *is_neg = \&is_negative;

    sub sign {
        my ($x) = @_;
        $x = Math::GMPq::Rmpq_sgn($$x);
        if ($x > 0) {
            ONE;
        }
        elsif (!$x) {
            ZERO;
        }
        else {
            MONE;
        }
    }

    sub popcount {
        my $z = _big2mpz($_[0]);
        Math::GMPz::Rmpz_neg($z, $z) if Math::GMPz::Rmpz_sgn($z) < 0;
        __PACKAGE__->_set_uint(Math::GMPz::Rmpz_popcount($z));
    }

    sub is_int {
        my ($x) = @_;
        Math::GMPq::Rmpq_integer_p($$x)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_real {
        my ($x) = @_;
        (Sidef::Types::Bool::Bool::TRUE);
    }

    sub is_even {
        my ($x) = @_;

        Math::GMPq::Rmpq_integer_p($$x)
          || return Sidef::Types::Bool::Bool::FALSE;

        Math::GMPz::Rmpz_even_p(Math::GMPz::Rmpz_init_set($$x))
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_odd {
        my ($x) = @_;

        Math::GMPq::Rmpq_integer_p($$x)
          || return Sidef::Types::Bool::Bool::FALSE;

        Math::GMPz::Rmpz_odd_p(Math::GMPz::Rmpz_init_set($$x))
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_div {
        my ($x, $y) = @_;
        _valid(\$y);

        Math::GMPq::Rmpq_sgn($$y)
          || return Sidef::Types::Bool::Bool::FALSE;

#<<<
        #---------------------------------------------------------------------------------
        ## Optimization for integers, but it turns out to be slower for small integers...
        #---------------------------------------------------------------------------------
        #~ if (Math::GMPq::Rmpq_integer_p($$y) and Math::GMPq::Rmpq_integer_p($$x)) {
            #~ my $d = CORE::int(CORE::abs(Math::GMPq::Rmpq_get_d($$y)));
            #~ if ($d <= MAX_UI) {
              #~ Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $$x);
               #~ return (
                    #~ Math::GMPz::Rmpz_divisible_ui_p($z, $d)
                    #~ ? Sidef::Types::Bool::Bool::TRUE
                    #~ : Sidef::Types::Bool::Bool::FALSE
                #~ );
            #~ }
            #~ else {
                #~ return (
                    #~ Math::GMPz::Rmpz_divisible_p(_big2mpz($x), _big2mpz($y))
                    #~ ? Sidef::Types::Bool::Bool::TRUE
                    #~ : Sidef::Types::Bool::Bool::FALSE
                #~ );
            #~ }
        #~ }
#>>>

        Math::GMPq::Rmpq_div((my $q = Math::GMPq::Rmpq_init()), $$x, $$y);

        Math::GMPq::Rmpq_integer_p($q)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub divides {
        my ($x, $y) = @_;
        _valid(\$y);

        Math::GMPq::Rmpq_sgn($$x)
          || return Sidef::Types::Bool::Bool::FALSE;

        Math::GMPq::Rmpq_div((my $q = Math::GMPq::Rmpq_init()), $$y, $$x);

        Math::GMPq::Rmpq_integer_p($q)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
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
        Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $q);
        _mpz2big($z);
    }

    sub float {
        Math::MPFR::Rmpfr_set_q((my $f = Math::MPFR::Rmpfr_init2($PREC)), ${$_[0]}, $ROUND);
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

        Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $q);
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
            Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $q);
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
            Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $q);
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
            Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $q);
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
            Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $q);
            Math::GMPz::Rmpz_get_str($z, 10);
          };

        $str =~ tr/-//d;
        Sidef::Types::Array::Array->new([map { __PACKAGE__->_set_uint($_) } split(//, $str)]);
    }

    sub digit {
        my ($x, $y) = @_;
        _valid(\$y);

        my $q = $$x;
        my $str =
            Math::GMPq::Rmpq_integer_p($q)
          ? Math::GMPq::Rmpq_get_str($q, 10)
          : do {
            Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $q);
            Math::GMPz::Rmpz_get_str($z, 10);
          };

        $str =~ tr/-//d;
        my $digit = substr($str, Math::GMPq::Rmpq_get_d($$y), 1);
        length($digit) ? __PACKAGE__->_set_uint($digit) : nan();
    }

    sub length {
        Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), ${$_[0]});
        Math::GMPz::Rmpz_abs($z, $z);

        #__PACKAGE__->_set_uint(Math::GMPz::Rmpz_sizeinbase($z, 10));        # turned out to be inexact
        __PACKAGE__->_set_uint(Math::GMPz::Rmpz_snprintf(my $buf, 0, "%Zd", $z, 0));
    }

    *len  = \&length;
    *size = \&length;

    sub floor {
        my ($x) = @_;
        $x = $$x;
        Math::GMPq::Rmpq_integer_p($x) && return $_[0];
        Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $x);
        Math::GMPz::Rmpz_sub_ui($z, $z, 1) if Math::GMPq::Rmpq_sgn($x) < 0;
        _mpz2big($z);
    }

    sub ceil {
        my ($x) = @_;
        $x = $$x;
        Math::GMPq::Rmpq_integer_p($x) && return $_[0];
        Math::GMPz::Rmpz_set_q((my $z = Math::GMPz::Rmpz_init()), $x);
        Math::GMPz::Rmpz_add_ui($z, $z, 1) if Math::GMPq::Rmpq_sgn($x) > 0;
        _mpz2big($z);
    }

    sub inc {
        my ($x) = @_;
        Math::GMPq::Rmpq_add((my $r = Math::GMPq::Rmpq_init()), $$x, $ONE);
        bless \$r, __PACKAGE__;
    }

    sub dec {
        my ($x) = @_;
        Math::GMPq::Rmpq_sub((my $r = Math::GMPq::Rmpq_init()), $$x, $ONE);
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

            $y = _big2mpz($y);
            my $sign_y = Math::GMPz::Rmpz_sgn($y) || return nan();

            $x = _big2mpz($x);
            Math::GMPz::Rmpz_mod($x, $x, $y);
            Math::GMPz::Rmpz_sgn($x) || return ZERO;
            Math::GMPz::Rmpz_add($x, $x, $y) if $sign_y < 0;
            _mpz2big($x);
        }
        else {
            $x = _big2mpfr($x);
            $y = _big2mpfr($y);
            Math::MPFR::Rmpfr_fmod($x, $x, $y, $ROUND);
            my $sign = Math::MPFR::Rmpfr_sgn($x) || return ZERO;
            if ($sign > 0 xor Math::MPFR::Rmpfr_sgn($y) > 0) {
                Math::MPFR::Rmpfr_add($x, $x, $y, $ROUND);
            }
            _mpfr2big($x);
        }
    }

    sub fmod {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return (Math::GMPq::Rmpq_sgn($$x) == Math::GMPq::Rmpq_sgn($$y) ? $x : $y);
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);

        $x = _big2mpfr($x);
        $y = _big2mpfr($y);

        Math::MPFR::Rmpfr_fmod($x, $x, $y, $ROUND);

        my $sign_r = Math::MPFR::Rmpfr_sgn($x);
        if (!$sign_r) {
            return ZERO;    # return faster
        }
        elsif ($sign_r > 0 xor Math::MPFR::Rmpfr_sgn($y) > 0) {
            Math::MPFR::Rmpfr_add($x, $x, $y, $ROUND);
        }

        _mpfr2big($x);
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

        $y = _big2mpz($y);
        my $sign_y = Math::GMPz::Rmpz_sgn($y);
        return nan() if !$sign_y;

        $x = _big2mpz($x);
        Math::GMPz::Rmpz_mod($x, $x, $y);
        Math::GMPz::Rmpz_sgn($x) || return ZERO;
        Math::GMPz::Rmpz_add($x, $x, $y) if $sign_y < 0;
        _mpz2big($x);
    }

    sub frem {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf' or ref($y) eq 'Sidef::Types::Number::Ninf') {
            return $x;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        _valid(\$y);
        $x = _big2mpfr($x);
        Math::MPFR::Rmpfr_fmod($x, $x, _big2mpfr($y), $ROUND);
        _mpfr2big($x);
    }

    sub modpow {
        my ($x, $y, $z) = @_;
        _valid(\$y, \$z);
        my $mod = _big2mpz($z);
        Math::GMPz::Rmpz_sgn($mod) || return nan();
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_powm($x, $x, _big2mpz($y), $mod);
        _mpz2big($x);
    }

    *expmod = \&modpow;
    *powmod = \&modpow;

    sub modinv {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_invert($x, $x, _big2mpz($y)) || return nan();
        _mpz2big($x);
    }

    *invmod = \&modinv;

    sub divmod {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _big2mpz($x);
        $y = _big2mpz($y);

        return (nan(), nan()) if !Math::GMPz::Rmpz_sgn($y);

        Math::GMPz::Rmpz_divmod($x, $y, $x, $y);
        (_mpz2big($x), _mpz2big($y));
    }

    sub and {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_and($x, $x, _big2mpz($y));
        _mpz2big($x);
    }

    sub or {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_ior($x, $x, _big2mpz($y));
        _mpz2big($x);
    }

    sub xor {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_xor($x, $x, _big2mpz($y));
        _mpz2big($x);
    }

    sub not {
        my ($x) = @_;
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_com($x, $x);
        _mpz2big($x);
    }

    sub ramanujan_tau {
        __PACKAGE__->_set_str(Math::Prime::Util::GMP::ramanujan_tau(&_big2istr));
    }

    sub factorial {
        my $n = CORE::int(Math::GMPq::Rmpq_get_d(${$_[0]}));
        return nan() if $n < 0;
        Math::GMPz::Rmpz_fac_ui((my $r = Math::GMPz::Rmpz_init()), $n);
        _mpz2big($r);
    }

    *fac = \&factorial;

    sub double_factorial {
        my $n = CORE::int(Math::GMPq::Rmpq_get_d(${$_[0]}));
        return nan() if $n < 0;
        Math::GMPz::Rmpz_2fac_ui((my $r = Math::GMPz::Rmpz_init()), $n);
        _mpz2big($r);
    }

    *dfac = \&double_factorial;

    sub primorial {
        my $n = CORE::int(Math::GMPq::Rmpq_get_d(${$_[0]}));
        return nan() if $n < 0;
        Math::GMPz::Rmpz_primorial_ui((my $r = Math::GMPz::Rmpz_init()), $n);
        _mpz2big($r);
    }

    sub pn_primorial {
        my $n = CORE::int(Math::GMPq::Rmpq_get_d(${$_[0]}));
        return nan() if $n < 0;
        __PACKAGE__->_set_str(Math::Prime::Util::GMP::pn_primorial($n));
    }

    sub lucas {
        my ($x) = @_;
        my $n = CORE::int(Math::GMPq::Rmpq_get_d($$x));
        return nan() if $n < 0;
        Math::GMPz::Rmpz_lucnum_ui((my $r = Math::GMPz::Rmpz_init()), $n);
        _mpz2big($r);
    }

    sub fibonacci {
        my ($x) = @_;
        my $n = CORE::int(Math::GMPq::Rmpq_get_d($$x));
        return nan() if $n < 0;
        Math::GMPz::Rmpz_fib_ui((my $r = Math::GMPz::Rmpz_init()), $n);
        _mpz2big($r);
    }

    *fib = \&fibonacci;

    sub stirling {
        my ($x, $y) = @_;
        _valid(\$y);
        my $n = Math::Prime::Util::GMP::stirling(_big2istr($x), _big2istr($y));
        __PACKAGE__->_set_str($n);
    }

    sub stirling2 {
        my ($x, $y) = @_;
        _valid(\$y);
        my $n = Math::Prime::Util::GMP::stirling(_big2istr($x), _big2istr($y), 2);
        __PACKAGE__->_set_str($n);
    }

    sub stirling3 {
        my ($x, $y) = @_;
        _valid(\$y);
        my $n = Math::Prime::Util::GMP::stirling(_big2istr($x), _big2istr($y), 3);
        __PACKAGE__->_set_str($n);
    }

    sub bell {
        my $n = Math::GMPq::Rmpq_get_d(${$_[0]});
        __PACKAGE__->_set_str(Math::Prime::Util::GMP::vecsum(map { Math::Prime::Util::GMP::stirling($n, $_, 2) } 0 .. $n));
    }

    sub binomial {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpz($x);
        my $i = CORE::int(Math::GMPq::Rmpq_get_d($$y));
        $i >= 0
          ? Math::GMPz::Rmpz_bin_ui($x, $x, $i)
          : Math::GMPz::Rmpz_bin_si($x, $x, $i);
        _mpz2big($x);
    }

    *nok = \&binomial;

    sub moebius {
        my $mob = Math::Prime::Util::GMP::moebius(&_big2istr);
        if (!$mob) {
            ZERO;
        }
        elsif ($mob == 1) {
            ONE;
        }
        else {
            MONE;
        }
    }

    *mobius = \&moebius;

    # Currently (0.41), this method is very slow for wide ranges.
    # It's included with the hope that it will become faster someday.
    sub prime_count {
        my ($x, $y) = @_;

        if (ref($y) eq 'Sidef::Types::Number::Inf') {
            return $y;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Ninf') {
            return ZERO;
        }
        elsif (ref($y) eq 'Sidef::Types::Number::Nan') {
            return nan();
        }

        my $n = defined($y)
          ? do {
            _valid(\$y);
            Math::Prime::Util::GMP::prime_count(_big2istr($x), _big2istr($y));
          }
          : Math::Prime::Util::GMP::prime_count(2, _big2istr($x));
        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    sub legendre {
        my ($x, $y) = @_;
        _valid(\$y);
        my $sym = Math::GMPz::Rmpz_legendre(_big2mpz($x), _big2mpz($y));
        if (!$sym) {
            ZERO;
        }
        elsif ($sym == 1) {
            ONE;
        }
        else {
            MONE;
        }
    }

    sub jacobi {
        my ($x, $y) = @_;
        _valid(\$y);
        my $sym = Math::GMPz::Rmpz_jacobi(_big2mpz($x), _big2mpz($y));
        if (!$sym) {
            ZERO;
        }
        elsif ($sym == 1) {
            ONE;
        }
        else {
            MONE;
        }
    }

    sub kronecker {
        my ($x, $y) = @_;
        _valid(\$y);
        my $sym = Math::GMPz::Rmpz_kronecker(_big2mpz($x), _big2mpz($y));
        if (!$sym) {
            ZERO;
        }
        elsif ($sym == 1) {
            ONE;
        }
        else {
            MONE;
        }
    }

    sub gcd {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_gcd($x, $x, _big2mpz($y));
        _mpz2big($x);
    }

    sub lcm {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_lcm($x, $x, _big2mpz($y));
        _mpz2big($x);
    }

    sub valuation {
        my ($x, $y) = @_;
        _valid(\$y);
        my $z = _big2mpz($y);
        my $sgn = Math::GMPz::Rmpz_sgn($z) || return ZERO;
        Math::GMPz::Rmpz_abs($z, $z) if $sgn < 0;
        $x = _big2mpz($x);
        __PACKAGE__->_set_uint(Math::GMPz::Rmpz_remove($x, $x, $z));
    }

    sub remove {
        my ($x, $y) = @_;
        _valid(\$y);
        my $z = _big2mpz($y);
        Math::GMPz::Rmpz_sgn($z) || return ZERO;
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_remove($x, $x, $z);
        _mpz2big($x);
    }

    sub is_prime {
        my $x = ${$_[0]};
        Math::GMPq::Rmpq_integer_p($x)
          && Math::Prime::Util::GMP::is_prime(Math::GMPq::Rmpq_get_str($x, 10))
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_prob_prime {
        my ($x, $k) = @_;
        $x = $$x;
        (
         Math::GMPq::Rmpq_integer_p($x)
           && Math::GMPz::Rmpz_probab_prime_p(Math::GMPz::Rmpz_init_set($x),
                                              defined($k) ? do { _valid(\$k); CORE::int Math::GMPq::Rmpq_get_d($$k) }
                                              : 20) > 0
          ) ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_prov_prime {
        my $x = ${$_[0]};
        Math::GMPq::Rmpq_integer_p($x)
          && Math::Prime::Util::GMP::is_provable_prime(Math::GMPq::Rmpq_get_str($x, 10))
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_mersenne_prime {
        my $x = ${$_[0]};
        Math::GMPq::Rmpq_integer_p($x)
          && Math::Prime::Util::GMP::is_mersenne_prime(Math::GMPq::Rmpq_get_str($x, 10))
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub primes {
        my ($x, $y) = @_;

        _valid(\$y) if defined($y);

        Sidef::Types::Array::Array->new(
            [
             map {

                 $_ <= MAX_UI
                   ? __PACKAGE__->_set_uint($_)
                   : __PACKAGE__->_set_str($_)
               }

               @{Math::Prime::Util::GMP::primes(_big2istr($x), defined($y) ? _big2istr($y) : ())}
            ]
        );
    }

    sub prev_prime {
        my $p = Math::Prime::Util::GMP::prev_prime(&_big2istr) || return nan();
        $p <= MAX_UI ? __PACKAGE__->_set_uint($p) : __PACKAGE__->_set_str($p);
    }

    sub next_prime {
        my ($x) = @_;
        $x = _big2mpz($x);
        Math::GMPz::Rmpz_nextprime($x, $x);
        _mpz2big($x);
    }

    sub znorder {
        my ($x, $y) = @_;
        _valid(\$y);
        my $n = Math::Prime::Util::GMP::znorder(_big2istr($x), _big2istr($y)) // return nan();
        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    sub znprimroot {
        my $n = Math::Prime::Util::GMP::znprimroot(&_big2istr) || return nan();
        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    sub rad {
        my ($n) = @_;
        state $x = require List::Util;
        my $n = Math::Prime::Util::GMP::vecprod(List::Util::uniq(Math::Prime::Util::GMP::factor(&_big2istr)));
        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    sub factor {
        Sidef::Types::Array::Array->new(
            [
             map {

                 $_ <= MAX_UI
                   ? __PACKAGE__->_set_uint($_)
                   : __PACKAGE__->_set_str($_)
               }

               Math::Prime::Util::GMP::factor(&_big2istr)
            ]
        );
    }

    *factors = \&factor;

    sub pfactor {
        my %count;
        foreach my $f (Math::Prime::Util::GMP::factor(&_big2istr)) {
            ++$count{$f};
        }

        my @pairs;
        foreach my $factor (sort { (CORE::length($a) <=> CORE::length($b)) || ($a cmp $b) } keys(%count)) {
            push @pairs,
              Sidef::Types::Array::Pair->new(
                                             (
                                              $factor <= MAX_UI
                                              ? __PACKAGE__->_set_uint($factor)
                                              : __PACKAGE__->_set_str($factor)
                                             ),
                                             __PACKAGE__->_set_uint($count{$factor})
                                            );
        }

        Sidef::Types::Array::Array->new(\@pairs);
    }

    *pfactors = \&pfactor;

    sub divisors {
        Sidef::Types::Array::Array->new(
            [
             map {

                 $_ <= MAX_UI
                   ? __PACKAGE__->_set_uint($_)
                   : __PACKAGE__->_set_str($_)
               }

               Math::Prime::Util::GMP::divisors(&_big2istr)
            ]
        );
    }

    sub exp_mangoldt {
        my $n = Math::Prime::Util::GMP::exp_mangoldt(&_big2istr);
        $n == 1 and return ONE;
        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    sub totient {
        my $n = Math::Prime::Util::GMP::totient(&_big2istr);
        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    *euler_phi     = \&totient;
    *euler_totient = \&totient;

    sub jordan_totient {
        my ($x, $y) = @_;
        _valid(\$y);
        my $n = Math::Prime::Util::GMP::jordan_totient(_big2istr($x), _big2istr($y));
        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    sub carmichael_lambda {
        my $n = Math::Prime::Util::GMP::carmichael_lambda(&_big2istr);
        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    sub liouville {
        Math::Prime::Util::GMP::liouville(&_big2istr) == 1 ? ONE : MONE;
    }

    sub big_omega {
        __PACKAGE__->_set_uint(scalar Math::Prime::Util::GMP::factor(&_big2istr));
    }

    sub omega {
        my %factors;
        undef @factors{Math::Prime::Util::GMP::factor(&_big2istr)};
        __PACKAGE__->_set_uint(scalar keys %factors);
    }

    sub sigma0 {
        my $n = Math::Prime::Util::GMP::sigma(&_big2istr, 0);
        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    sub sigma {
        my ($x, $y) = @_;

        my $n = defined($y)
          ? do {
            _valid(\$y);
            Math::Prime::Util::GMP::sigma(_big2istr($x), _big2istr($y));
          }
          : Math::Prime::Util::GMP::sigma(&_big2istr, 1);

        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    sub partitions {
        my $n = Math::Prime::Util::GMP::partitions(&_big2istr);
        $n <= MAX_UI ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str($n);
    }

    sub is_primitive_root {
        my ($x, $y) = @_;
        _valid(\$y);
        Math::GMPq::Rmpq_integer_p($$x)
          && Math::GMPq::Rmpq_integer_p($$y)
          && Math::Prime::Util::GMP::is_primitive_root(_big2istr($x), _big2istr($y))
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_square_free {
        my $x = ${$_[0]};
        Math::GMPq::Rmpq_integer_p($x)
          && Math::Prime::Util::GMP::moebius(Math::GMPq::Rmpq_get_str($x, 10))
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_square {
        my $x = ${$_[0]};
        Math::GMPq::Rmpq_integer_p($x)
          && Math::GMPz::Rmpz_perfect_square_p(Math::GMPz::Rmpz_init_set($x))
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    *is_sqr = \&is_square;

    sub is_power {
        my ($x, $y) = @_;

        $x = $$x;

        Math::GMPq::Rmpq_integer_p($x)
          || return Sidef::Types::Bool::Bool::FALSE;

        if (defined $y) {
            _valid(\$y);

            Math::GMPq::Rmpq_equal($x, $ONE)
              && return Sidef::Types::Bool::Bool::TRUE;

            $y = CORE::int(Math::GMPq::Rmpq_get_d($$y));

            # Everything is a first power
            $y == 1 and return Sidef::Types::Bool::Bool::TRUE;

            # Return a true value when $x=-1 and $y is odd
            $y % 2
              and Math::GMPq::Rmpq_equal($x, $MONE)
              and return Sidef::Types::Bool::Bool::TRUE;

            # Don't accept a non-positive power
            # Also, when $x is negative and $y is even, return faster
            if ($y <= 0 or ($y % 2 == 0 and Math::GMPq::Rmpq_sgn($x) < 0)) {
                return Sidef::Types::Bool::Bool::FALSE;
            }

            my $z = Math::GMPz::Rmpz_init_set($x);

            # Optimization for perfect squares (thanks to Dana Jacobsen)
            $y == 2
              and return (
                          Math::GMPz::Rmpz_perfect_square_p($z)
                          ? Sidef::Types::Bool::Bool::TRUE
                          : Sidef::Types::Bool::Bool::FALSE
                         );

            Math::GMPz::Rmpz_perfect_power_p($z)
              || return Sidef::Types::Bool::Bool::FALSE;

            Math::GMPz::Rmpz_root($z, $z, $y)
              ? Sidef::Types::Bool::Bool::TRUE
              : Sidef::Types::Bool::Bool::FALSE;
        }
        else {
            Math::GMPz::Rmpz_perfect_power_p(Math::GMPz::Rmpz_init_set($x))
              ? Sidef::Types::Bool::Bool::TRUE
              : Sidef::Types::Bool::Bool::FALSE;
        }
    }

    *is_pow = \&is_power;

    sub is_prime_power {
        my $x = ${$_[0]};
        Math::GMPq::Rmpq_integer_p($x)
          && Math::Prime::Util::GMP::is_prime_power(Math::GMPq::Rmpq_get_str($x, 10))
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub prime_root {
        my $str = &_big2istr;

        my $pow = Math::Prime::Util::GMP::is_prime_power($str) || return nan();
        $pow == 1 and return $_[0];

        my $x = Math::GMPz::Rmpz_init_set_str($str, 10);
        $pow == 2
          ? Math::GMPz::Rmpz_sqrt($x, $x)
          : Math::GMPz::Rmpz_root($x, $x, $pow);
        _mpz2big($x);
    }

    sub prime_power {
        my $pow = Math::Prime::Util::GMP::is_prime_power(&_big2istr) || return ZERO;
        $pow == 1 ? ONE : __PACKAGE__->_set_uint($pow);
    }

    sub perfect_root {
        my $str = &_big2istr;

        my $pow = Math::Prime::Util::GMP::is_power($str) || return $_[0];

        my $x = Math::GMPz::Rmpz_init_set_str($str, 10);
        $pow == 2
          ? Math::GMPz::Rmpz_sqrt($x, $x)
          : Math::GMPz::Rmpz_root($x, $x, $pow);
        _mpz2big($x);
    }

    sub perfect_power {
        __PACKAGE__->_set_uint(Math::Prime::Util::GMP::is_power(&_big2istr) || return ONE);
    }

    sub next_pow2 {
        my ($x) = @_;

        Math::MPFR::Rmpfr_set_z((my $f = Math::MPFR::Rmpfr_init2($PREC)), _big2mpz($x), $PREC);
        Math::MPFR::Rmpfr_log2($f, $f, $ROUND);
        Math::MPFR::Rmpfr_ceil($f, $f);

        my $ui = Math::MPFR::Rmpfr_get_ui($f, $ROUND);
        my $z = Math::GMPz::Rmpz_init_set_ui(1);
        Math::GMPz::Rmpz_mul_2exp($z, $z, $ui);
        _mpz2big($z);
    }

    *next_power2 = \&next_pow2;

    sub next_pow {
        my ($x, $y) = @_;

        _valid(\$y);

        Math::MPFR::Rmpfr_set_z((my $f1 = Math::MPFR::Rmpfr_init2($PREC)), _big2mpz($x), $PREC);
        Math::MPFR::Rmpfr_log($f1, $f1, $ROUND);

        Math::MPFR::Rmpfr_set_z((my $f2 = Math::MPFR::Rmpfr_init2($PREC)), _big2mpz($y), $PREC);
        Math::MPFR::Rmpfr_log($f2, $f2, $ROUND);

        Math::MPFR::Rmpfr_div($f1, $f1, $f2, $ROUND);
        Math::MPFR::Rmpfr_ceil($f1, $f1);

        my $ui = Math::MPFR::Rmpfr_get_ui($f1, $ROUND);

        $y = _big2mpz($y);
        Math::GMPz::Rmpz_pow_ui($y, $y, $ui);
        _mpz2big($y);
    }

    *next_power = \&next_pow;

    sub shift_left {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpz($x);
        my $i = CORE::int(Math::GMPq::Rmpq_get_d($$y));
        if ($i < 0) {
            Math::GMPz::Rmpz_div_2exp($x, $x, CORE::abs($i));
        }
        else {
            Math::GMPz::Rmpz_mul_2exp($x, $x, $i);
        }
        _mpz2big($x);
    }

    sub shift_right {
        my ($x, $y) = @_;
        _valid(\$y);
        $x = _big2mpz($x);
        my $i = CORE::int(Math::GMPq::Rmpq_get_d($$y));
        if ($i < 0) {
            Math::GMPz::Rmpz_mul_2exp($x, $x, CORE::abs($i));
        }
        else {
            Math::GMPz::Rmpz_div_2exp($x, $x, $i);
        }
        _mpz2big($x);
    }

    #
    ## Rational specific
    #

    sub numerator {
        my ($x) = @_;
        Math::GMPq::Rmpq_numref((my $z = Math::GMPz::Rmpz_init()), $$x);
        Math::GMPq::Rmpq_set_z((my $r = Math::GMPq::Rmpq_init()), $z);
        bless \$r, __PACKAGE__;
    }

    *nu = \&numerator;

    sub denominator {
        my ($x) = @_;
        Math::GMPq::Rmpq_denref((my $z = Math::GMPz::Rmpz_init()), $$x);
        Math::GMPq::Rmpq_set_z((my $r = Math::GMPq::Rmpq_init()), $z);
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

        Math::GMPq::Rmpq_set((my $n = Math::GMPq::Rmpq_init()), $$x);
        Math::GMPq::Rmpq_abs($n, $n) if $sgn < 0;

        Math::GMPq::Rmpq_set_str((my $p = Math::GMPq::Rmpq_init()), '1' . ('0' x CORE::abs($nth)), 10);

        ($nth < 0)
          ? Math::GMPq::Rmpq_div($n, $n, $p)
          : Math::GMPq::Rmpq_mul($n, $n, $p);

        state $half = do {
            my $q = Math::GMPq::Rmpq_init_nobless();
            Math::GMPq::Rmpq_set_ui($q, 1, 2);
            $q;
        };

        my $z = Math::GMPz::Rmpz_init();
        Math::GMPq::Rmpq_add($n, $n, $half);
        Math::GMPz::Rmpz_set_q($z, $n);

        if (Math::GMPz::Rmpz_odd_p($z) and Math::GMPq::Rmpq_integer_p($n)) {
            Math::GMPz::Rmpz_sub_ui($z, $z, 1);
        }

        Math::GMPq::Rmpq_set_z($n, $z);

        ($nth < 0)
          ? Math::GMPq::Rmpq_mul($n, $n, $p)
          : Math::GMPq::Rmpq_div($n, $n, $p);

        Math::GMPq::Rmpq_neg($n, $n) if $sgn < 0;

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

    {
        state $state = Math::MPFR::Rmpfr_randinit_mt_nobless();
        Math::MPFR::Rmpfr_randseed_ui($state, scalar srand());

        sub rand {
            my ($x, $y) = @_;

            Math::MPFR::Rmpfr_urandom((my $rand = Math::MPFR::Rmpfr_init2($PREC)), $state, $ROUND);
            Math::MPFR::Rmpfr_get_q((my $q = Math::GMPq::Rmpq_init()), $rand);

            if (defined $y) {

                if (   ref($y) eq 'Sidef::Types::Number::Inf'
                    or ref($y) eq 'Sidef::Types::Number::Ninf'
                    or ref($y) eq 'Sidef::Types::Number::Nan') {
                    return $y;
                }

                _valid(\$y);

                Math::GMPq::Rmpq_sub((my $diff = Math::GMPq::Rmpq_init()), $$y, $$x);
                Math::GMPq::Rmpq_mul($q, $q, $diff);
                Math::GMPq::Rmpq_add($q, $q, $$x);
            }
            else {
                Math::GMPq::Rmpq_mul($q, $q, $$x);
            }

            bless \$q, __PACKAGE__;
        }

        sub seed {
            Math::MPFR::Rmpfr_randseed($state, _big2mpz($_[0]));
            $_[0];
        }
    }

    {
        state $state = Math::GMPz::zgmp_randinit_mt_nobless();
        Math::GMPz::zgmp_randseed_ui($state, scalar srand());

        sub irand {
            my ($x, $y) = @_;

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

        sub iseed {
            Math::GMPz::zgmp_randseed($state, _big2mpz($_[0]));
            $_[0];
        }
    }

    sub of {
        my ($x, $obj) = @_;

        if (ref($obj) eq 'Sidef::Types::Block::Block') {

            $x = _big2mpz($x);

            my @array;
            for (my $i = Math::GMPz::Rmpz_init_set_ui(1) ;
                 Math::GMPz::Rmpz_cmp($i, $x) <= 0 ;
                 Math::GMPz::Rmpz_add_ui($i, $i, 1)) {
                Math::GMPq::Rmpq_set_z((my $n = Math::GMPq::Rmpq_init()), $i);
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
            Math::GMPq::Rmpq_set_z((my $n = Math::GMPq::Rmpq_init()), $i);
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
            Math::GMPq::Rmpq_set_z((my $n = Math::GMPq::Rmpq_init()), $i);
            $block->run(bless(\$n, __PACKAGE__));
        }

        $block;
    }

    sub itimes {
        my ($num, $block) = @_;

        $num = _big2mpz($num);

        for (my $i = Math::GMPz::Rmpz_init_set_ui(0) ; Math::GMPz::Rmpz_cmp($i, $num) < 0 ; Math::GMPz::Rmpz_add_ui($i, $i, 1))
        {
            Math::GMPq::Rmpq_set_z((my $n = Math::GMPq::Rmpq_init()), $i);
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
        state $factor = do {
            Math::MPFR::Rmpfr_const_pi((my $pi = Math::MPFR::Rmpfr_init2($PREC)), $ROUND);
            Math::MPFR::Rmpfr_ui_div((my $fr = Math::MPFR::Rmpfr_init2($PREC)), 180, $pi, $ROUND);
            _mpfr2big($fr);
        };
        $factor->mul($x);
    }

    sub deg2rad {
        my ($x) = @_;
        state $factor = do {
            Math::MPFR::Rmpfr_const_pi((my $pi = Math::MPFR::Rmpfr_init2($PREC)), $ROUND);
            Math::MPFR::Rmpfr_div_ui((my $fr = Math::MPFR::Rmpfr_init2($PREC)), $pi, 180, $ROUND);
            _mpfr2big($fr);
        };
        $factor->mul($x);
    }

    sub rad2grad {
        my ($x) = @_;
        state $factor = do {
            Math::MPFR::Rmpfr_const_pi((my $pi = Math::MPFR::Rmpfr_init2($PREC)), $ROUND);
            Math::MPFR::Rmpfr_ui_div((my $fr = Math::MPFR::Rmpfr_init2($PREC)), 200, $pi, $ROUND);
            _mpfr2big($fr);
        };
        $factor->mul($x);
    }

    sub grad2rad {
        my ($x) = @_;
        state $factor = do {
            Math::MPFR::Rmpfr_const_pi((my $pi = Math::MPFR::Rmpfr_init2($PREC)), $ROUND);
            Math::MPFR::Rmpfr_div_ui((my $fr = Math::MPFR::Rmpfr_init2($PREC)), $pi, 200, $ROUND);
            _mpfr2big($fr);
        };
        $factor->mul($x);
    }

    sub grad2deg {
        my ($x) = @_;
        state $factor = do {
            Math::GMPq::Rmpq_set_ui((my $q = Math::GMPq::Rmpq_init_nobless()), 9, 10);
            $q;
        };
        Math::GMPq::Rmpq_mul((my $r = Math::GMPq::Rmpq_init()), $factor, $$x);
        bless \$r, __PACKAGE__;
    }

    sub deg2grad {
        my ($x) = @_;
        state $factor = do {
            Math::GMPq::Rmpq_set_ui((my $q = Math::GMPq::Rmpq_init_nobless()), 10, 9);
            $q;
        };
        Math::GMPq::Rmpq_mul((my $r = Math::GMPq::Rmpq_init()), $factor, $$x);
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
        *{__PACKAGE__ . '::' . 'ϕ'}  = \&euler_totient;
        *{__PACKAGE__ . '::' . 'σ'}  = \&sigma;
        *{__PACKAGE__ . '::' . 'Ω'}  = \&big_omega;
        *{__PACKAGE__ . '::' . 'ω'}  = \&omega;
        *{__PACKAGE__ . '::' . 'ζ'}  = \&zeta;
        *{__PACKAGE__ . '::' . 'η'}  = \&eta;
        *{__PACKAGE__ . '::' . 'μ'}  = \&mobius;
    }
}

1
