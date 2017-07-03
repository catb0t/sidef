package Sidef::Types::Number::Number {

    use utf8;
    use 5.016;

    use Math::MPFR qw();
    use Math::GMPq qw();
    use Math::GMPz qw();
    use Math::MPC qw();

    use Math::Prime::Util::GMP qw();
    use POSIX qw(ULONG_MAX LONG_MIN);

    our ($ROUND, $PREC);

    BEGIN {
        $ROUND = Math::MPFR::MPFR_RNDN();
        $PREC  = 192;
    }

    my $ONE  = Math::GMPz::Rmpz_init_set_ui(1);
    my $ZERO = Math::GMPz::Rmpz_init_set_ui(0);
    my $MONE = Math::GMPz::Rmpz_init_set_si(-1);

#<<<
    use constant {
          ONE  => bless(\$ONE),
          ZERO => bless(\$ZERO),
          MONE => bless(\$MONE),
    };
#>>>

    use parent qw(
      Sidef::Object::Object
      Sidef::Convert::Convert
      );

    use overload
      q{bool} => sub { (@_) = (${$_[0]}); goto &__boolify__ },
      q{0+}   => sub { (@_) = (${$_[0]}); goto &__numify__ },
      q{""}   => sub { (@_) = (${$_[0]}); goto &__stringify__ };

    use Sidef::Types::Bool::Bool;

    my @cache = (ZERO, ONE);

    sub new {
        my (undef, $num, $base) = @_;

        if (ref($base)) {
            if (ref($base) eq __PACKAGE__) {
                $base = _any2ui($$base) // 0;
            }
            else {
                $base = CORE::int($base);
            }
        }

        my $ref = ref($num);

        # Special string values
        if (!$ref and (!defined($base) or $base == 10)) {
            return bless \_str2obj($num);
        }

        # Number with base
        elsif (defined($base) and $base != 10) {

            my $int_base = CORE::int($base);

            if ($int_base < 2 or $int_base > 36) {
                die "[ERROR] Number(): base must be between 2 and 36, got $base";
            }

            $num = defined($num) ? "$num" : '0';

            if (index($num, '/') != -1) {
                my $r = Math::GMPq::Rmpq_init();
                eval { Math::GMPq::Rmpq_set_str($r, $num, $int_base); 1 } // goto &nan;
                if (Math::GMPq::Rmpq_get_str($r, 10) !~ m{^\s*[-+]?[0-9]+\s*/\s*[-+]?[1-9]+[0-9]*\s*\z}) {
                    goto &nan;
                }
                Math::GMPq::Rmpq_canonicalize($r);
                return bless \$r;
            }
            elsif (substr($num, 0, 1) eq '(' and substr($num, -1) eq ')') {
                my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
                if (Math::MPC::Rmpc_set_str($r, $num, $int_base, $ROUND)) {
                    goto &nan;
                }
                return bless \$r;
            }
            elsif (index($num, '.') != -1) {
                my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
                if (Math::MPFR::Rmpfr_set_str($r, $num, $int_base, $ROUND)) {
                    goto &nan;
                }
                return bless \$r;
            }
            else {
                my $r = eval { Math::GMPz::Rmpz_init_set_str($num, $int_base) } // goto &nan;
                return bless \$r;
            }
        }

        # Special objects
        elsif ($ref eq __PACKAGE__) {
            return $num;
        }

        # GMPz
        elsif ($ref eq 'Math::GMPz') {
            return bless \Math::GMPz::Rmpz_init_set($num);
        }

        # MPFR
        elsif ($ref eq 'Math::MPFR') {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set($r, $num, $ROUND);
            return bless \$r;
        }

        # MPC
        elsif ($ref eq 'Math::MPC') {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set($r, $num, $ROUND);
            return bless \$r;
        }

        # GMPq
        elsif ($ref eq 'Math::GMPq') {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set($r, $num);
            return bless \$r;
        }

        bless \_str2obj("$num");
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
                 : do {
                     my (undef, undef, undef, $caller) = caller(1);
                     die "[ERROR] Value <<$$_>> cannot be implicitly converted to a number, inside <<$caller>>!\n";
                   }
             );

             if (ref($tmp) ne __PACKAGE__) {    # this should not happen
                 my (undef, undef, undef, $caller) = caller(1);
                 die "[ERROR] Cannot convert <<$$_>> to a number, inside <<$caller>>! (is method \"to_n\" well-defined?)\n";
             }

             $$_ = $tmp;
           }
        ) for @_;
    }

    sub _set_uint {
        $_[1] <= 8192
          ? exists($cache[$_[1]])
              ? $cache[$_[1]]
              : ($cache[$_[1]] = bless \Math::GMPz::Rmpz_init_set_ui($_[1]))
          : bless \Math::GMPz::Rmpz_init_set_ui($_[1]);
    }

    sub _set_int {
        $_[1] == -1 && return MONE;
        $_[1] >= 0  && goto &_set_uint;
        bless \Math::GMPz::Rmpz_init_set_si($_[1]);
    }

    sub _dump {
        my $x = ${$_[0]};

        my $ref = ref($x);

        if ($ref eq 'Math::GMPz') {
            ('int', Math::GMPz::Rmpz_get_str($x, 10));
        }
        elsif ($ref eq 'Math::GMPq') {
            ('rat', Math::GMPq::Rmpq_get_str($x, 10));
        }
        elsif ($ref eq 'Math::MPFR') {
            ('float', Math::MPFR::Rmpfr_get_str($x, 10, 0, $ROUND));
        }
        elsif ($ref eq 'Math::MPC') {
            ('complex', Math::MPC::Rmpc_get_str(10, 0, $x, $ROUND));
        }
        else {
            die "[ERROR] This shouldn't happen: <<$x>> as <<$ref>>";
        }
    }

    sub _set_str {
        my (undef, $type, $str) = @_;

        if ($type eq 'int') {
            bless \Math::GMPz::Rmpz_init_set_str($str, 10);
        }
        elsif ($type eq 'rat') {
            Math::GMPq::Rmpq_set_str((my $r = Math::GMPq::Rmpq_init()), $str, 10);
            bless \$r;
        }
        elsif ($type eq 'float') {
            Math::MPFR::Rmpfr_set_str((my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC))), $str, 10, $ROUND);
            bless \$r;
        }
        elsif ($type eq 'complex') {
            Math::MPC::Rmpc_set_str((my $r = Math::MPC::Rmpc_init2(CORE::int($PREC))), $str, 10, $ROUND);
            bless \$r;
        }
        else {
            die "[ERROR] Number._set_str(): invalid type <<$type>> with content <<$str>>";
        }
    }

    sub _str2frac {
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
            if (CORE::abs($exp) >= 1000000) {
                Math::MPFR::Rmpfr_set_str((my $mpfr = Math::MPFR::Rmpfr_init2(CORE::int($PREC))), "$sign$str", 10, $ROUND);
                Math::MPFR::Rmpfr_get_q((my $mpq = Math::GMPq::Rmpq_init()), $mpfr);
                return Math::GMPq::Rmpq_get_str($mpq, 10);
            }

            my ($before, $after) = split(/\./, substr($str, 0, $i));

            if (!defined($after)) {    # return faster for numbers like "13e2"
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
                $denominator .= '0' x (CORE::abs($exp) + CORE::length($after));
            }
            else {
                my $diff = ($exp - CORE::length($after));
                if ($diff >= 0) {
                    $numerator .= '0' x $diff;
                }
                else {
                    my $s = "$before$after";
                    substr($s, $exp + CORE::length($before), 0, '.');
                    return __SUB__->("$sign$s");
                }
            }

            "$sign$numerator/$denominator";
        }
        elsif (($i = index($str, '.')) != -1) {
            my ($before, $after) = (substr($str, 0, $i), substr($str, $i + 1));
            if (($after =~ tr/0//) == CORE::length($after)) {
                return "$sign$before";
            }
            $sign . ("$before$after/1" =~ s/^0+//r) . ('0' x CORE::length($after));
        }
        else {
            "$sign$str";
        }
    }

    #
    ## Misc internal functions
    #

    # Converts a string into an mpq object
    sub _str2obj {
        my ($s) = @_;

        $s
          || return Math::GMPz::Rmpz_init_set_ui(0);

        $s = lc($s);

        if ($s eq 'inf' or $s eq '+inf') {
            goto &_inf;
        }
        elsif ($s eq '-inf') {
            goto &_ninf;
        }
        elsif ($s eq 'nan') {
            goto &_nan;
        }

        # Remove underscores
        $s =~ tr/_//d;

        # Performance improvement for Perl integers
        if (CORE::int($s) eq $s and $s >= LONG_MIN and $s <= ULONG_MAX) {
            return (
                    $s < 0
                    ? Math::GMPz::Rmpz_init_set_si($s)
                    : Math::GMPz::Rmpz_init_set_ui($s)
                   );
        }

        # Floating-point
        if ($s =~ /^([+-]?+(?=\.?[0-9])[0-9_]*+(?:\.[0-9_]++)?(?:[Ee](?:[+-]?+[0-9_]+))?)\z/) {
            my $frac = _str2frac($1);

            if (index($frac, '/') != -1) {
                my $q = Math::GMPq::Rmpq_init();
                Math::GMPq::Rmpq_set_str($q, $frac, 10);
                Math::GMPq::Rmpq_canonicalize($q);
                return $q;
            }
            else {
                my $z = Math::GMPz::Rmpz_init();
                Math::GMPz::Rmpz_set_str($z, $frac, 10);
                return $z;
            }
        }

        # Complex number
        if (substr($s, -1) eq 'i') {

            if ($s eq 'i' or $s eq '+i') {
                my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
                Math::MPC::Rmpc_set_ui_ui($r, 0, 1, $ROUND);
                return $r;
            }
            elsif ($s eq '-i') {
                my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
                Math::MPC::Rmpc_set_si_si($r, 0, -1, $ROUND);
                return $r;
            }

            my ($re, $im);

            state $numeric_re  = qr/[+-]?+(?=\.?[0-9])[0-9]*+(?:\.[0-9]++)?(?:[Ee](?:[+-]?+[0-9]+))?/;
            state $unsigned_re = qr/(?=\.?[0-9])[0-9]*+(?:\.[0-9]++)?(?:[Ee](?:[+-]?+[0-9]+))?/;

            if ($s =~ /^($numeric_re)\s*([-+])\s*($unsigned_re)i\z/o) {
                ($re, $im) = ($1, $3);
                $im = "-$im" if $2 eq '-';
            }
            elsif ($s =~ /^($numeric_re)i\z/o) {
                ($re, $im) = (0, $1);
            }
            elsif ($s =~ /^($numeric_re)\s*([-+])\s*i\z/o) {
                ($re, $im) = ($1, 1);
                $im = -1 if $2 eq '-';
            }

            if (defined($re) and defined($im)) {

                my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));

                $re = _str2obj($re);
                $im = _str2obj($im);

                my $sig = join(' ', ref($re), ref($im));

                if ($sig eq q{Math::MPFR Math::MPFR}) {
                    Math::MPC::Rmpc_set_fr_fr($r, $re, $im, $ROUND);
                }
                elsif ($sig eq q{Math::GMPz Math::GMPz}) {
                    Math::MPC::Rmpc_set_z_z($r, $re, $im, $ROUND);
                }
                elsif ($sig eq q{Math::GMPz Math::MPFR}) {
                    Math::MPC::Rmpc_set_z_fr($r, $re, $im, $ROUND);
                }
                elsif ($sig eq q{Math::MPFR Math::GMPz}) {
                    Math::MPC::Rmpc_set_fr_z($r, $re, $im, $ROUND);
                }
                else {    # this should never happen
                    $re = _any2mpfr($re);
                    $im = _any2mpfr($im);
                    Math::MPC::Rmpc_set_fr_fr($r, $re, $im, $ROUND);
                }

                return $r;
            }
        }

        # Floating point value
        if ($s =~ tr/e.//) {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            if (Math::MPFR::Rmpfr_set_str($r, $s, 10, $ROUND)) {
                Math::MPFR::Rmpfr_set_nan($r);
            }
            return $r;
        }

        # Fractional value
        if (index($s, '/') != -1 and $s =~ m{^\s*[-+]?[0-9]+\s*/\s*[-+]?[1-9]+[0-9]*\s*\z}) {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_str($r, $s, 10);
            Math::GMPq::Rmpq_canonicalize($r);
            return $r;
        }

        $s =~ s/^\+//;

        eval { Math::GMPz::Rmpz_init_set_str($s, 10) } // goto &_nan;
    }

    #
    ## MPZ
    #
    sub _mpz2mpq {
        my $r = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_z($r, $_[0]);
        $r;
    }

    sub _mpz2mpfr {
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_set_z($r, $_[0], $ROUND);
        $r;
    }

    sub _mpz2mpc {
        my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
        Math::MPC::Rmpc_set_z($r, $_[0], $ROUND);
        $r;
    }

    #
    ## MPQ
    #
    sub _mpq2mpz {
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_set_q($z, $_[0]);
        $z;
    }

    sub _mpq2mpfr {
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_set_q($r, $_[0], $ROUND);
        $r;
    }

    sub _mpq2mpc {
        my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
        Math::MPC::Rmpc_set_q($r, $_[0], $ROUND);
        $r;
    }

    #
    ## MPFR
    #
    sub _mpfr2mpc {
        my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
        Math::MPC::Rmpc_set_fr($r, $_[0], $ROUND);
        $r;
    }

    #
    ## Any to MPC (complex)
    #
    sub _any2mpc {
        my ($x) = @_;

        ref($x) eq 'Math::MPC'  && return $x;
        ref($x) eq 'Math::GMPq' && goto &_mpq2mpc;
        ref($x) eq 'Math::GMPz' && goto &_mpz2mpc;

        goto &_mpfr2mpc;
    }

    #
    ## Any to MPFR (floating-point)
    #
    sub _any2mpfr {
        my ($x) = @_;

        ref($x) eq 'Math::MPFR' && return $x;
        ref($x) eq 'Math::GMPq' && goto &_mpq2mpfr;
        ref($x) eq 'Math::GMPz' && goto &_mpz2mpfr;

        my $fr = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPC::RMPC_IM($fr, $x);

        if (Math::MPFR::Rmpfr_zero_p($fr)) {
            Math::MPC::RMPC_RE($fr, $x);
        }
        else {
            Math::MPFR::Rmpfr_set_nan($fr);
        }

        $fr;
    }

    #
    ## Any to MPFR or MPC, in this order
    #
    sub _any2mpfr_mpc {
        my ($x) = @_;

        if (   ref($x) eq 'Math::MPFR'
            or ref($x) eq 'Math::MPC') {
            return $x;
        }

        ref($x) eq 'Math::GMPz' && goto &_mpz2mpfr;
        ref($x) eq 'Math::GMPq' && goto &_mpq2mpfr;
        goto &_any2mpfr;    # this should not happen
    }

    #
    ## Any to GMPz (integer)
    #
    sub _any2mpz {
        my ($x) = @_;

        ref($x) eq 'Math::GMPz' && return $x;
        ref($x) eq 'Math::GMPq' && goto &_mpq2mpz;

        if (ref($x) eq 'Math::MPFR') {
            if (Math::MPFR::Rmpfr_number_p($x)) {
                my $z = Math::GMPz::Rmpz_init();
                Math::MPFR::Rmpfr_get_z($z, $x, Math::MPFR::MPFR_RNDZ);
                return $z;
            }
            return;
        }

        (@_) = _any2mpfr($x);
        goto &_any2mpz;
    }

    #
    ## Any to GMPq (rational)
    #
    sub _any2mpq {
        my ($x) = @_;

        ref($x) eq 'Math::GMPq' && return $x;
        ref($x) eq 'Math::GMPz' && goto &_mpz2mpq;

        if (ref($x) eq 'Math::MPFR') {
            if (Math::MPFR::Rmpfr_number_p($x)) {
                my $q = Math::GMPq::Rmpq_init();
                Math::MPFR::Rmpfr_get_q($q, $x);
                return $q;
            }
            return;
        }

        (@_) = _any2mpfr($x);
        goto &_any2mpq;
    }

    #
    ## Any to unsigned integer
    #
    sub _any2ui {
        my ($x) = @_;

        if (ref($x) eq 'Math::GMPz') {
            my $d = CORE::int(Math::GMPz::Rmpz_get_d($x));
            ($d < 0 or $d > ULONG_MAX) && return;
            return $d;
        }

        if (ref($x) eq 'Math::GMPq') {
            my $d = CORE::int(Math::GMPq::Rmpq_get_d($x));
            ($d < 0 or $d > ULONG_MAX) && return;
            return $d;
        }

        if (ref($x) eq 'Math::MPFR') {
            if (Math::MPFR::Rmpfr_number_p($x)) {
                my $d = CORE::int(Math::MPFR::Rmpfr_get_d($x, $ROUND));
                ($d < 0 or $d > ULONG_MAX) && return;
                return $d;
            }
            return;
        }

        (@_) = _any2mpfr($x);
        goto &_any2ui;
    }

    #
    ## Any to signed integer
    #
    sub _any2si {
        my ($x) = @_;

        if (ref($x) eq 'Math::GMPz') {
            my $d = CORE::int(Math::GMPz::Rmpz_get_d($x));
            ($d < LONG_MIN or $d > ULONG_MAX) && return;
            return $d;
        }

        if (ref($x) eq 'Math::GMPq') {
            my $d = CORE::int(Math::GMPq::Rmpq_get_d($x));
            ($d < LONG_MIN or $d > ULONG_MAX) && return;
            return $d;
        }

        if (ref($x) eq 'Math::MPFR') {
            if (Math::MPFR::Rmpfr_number_p($x)) {
                my $d = CORE::int(Math::MPFR::Rmpfr_get_d($x, $ROUND));
                ($d < LONG_MIN or $d > ULONG_MAX) && return;
                return $d;
            }
            return;
        }

        (@_) = _any2mpfr($x);
        goto &_any2si;
    }

    sub _big2istr {
        my ($x) = @_;
        Math::GMPz::Rmpz_get_str((_any2mpz($$x) // return undef), 10);
    }

    sub _big2uistr {
        my ($x) = @_;
        my $str = Math::GMPz::Rmpz_get_str((_any2mpz($$x) // return undef), 10);
        $str < 0 && return undef;
        "$str";
    }

    #
    ## Internal conversion methods
    #

    sub __boolify__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            return !Math::MPFR::Rmpfr_zero_p($x);
        }

      Math_GMPq: {
            return !!Math::GMPq::Rmpq_sgn($x);
        }

      Math_GMPz: {
            return !!Math::GMPz::Rmpz_sgn($x);
        }

      Math_MPC: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::RMPC_RE($r, $x);
            Math::MPFR::Rmpfr_zero_p($r) || return 1;
            Math::MPC::RMPC_IM($r, $x);
            return !Math::MPFR::Rmpfr_zero_p($r);
        }
    }

    sub __numify__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            return Math::MPFR::Rmpfr_get_d($x, $ROUND);
        }

      Math_GMPq: {
            goto &Math::GMPq::Rmpq_get_d;
        }

      Math_GMPz: {
            goto &Math::GMPz::Rmpz_get_d;
        }

      Math_MPC: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::RMPC_RE($r, $x);
            return Math::MPFR::Rmpfr_get_d($r, $ROUND);
        }
    }

    sub __stringify__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_GMPz: {
            return Math::GMPz::Rmpz_get_str($x, 10);
        }

      Math_GMPq: {

            #~ return Math::GMPq::Rmpq_get_str($x, 10);
            Math::GMPq::Rmpq_integer_p($x) && return Math::GMPq::Rmpq_get_str($x, 10);

            $PREC = CORE::int($PREC) if ref($PREC);

            my $prec = $PREC >> 2;
            my $sgn  = Math::GMPq::Rmpq_sgn($x);

            my $n = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set($n, $x);
            Math::GMPq::Rmpq_abs($n, $n) if $sgn < 0;

            my $p = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_str($p, '1' . ('0' x CORE::abs($prec)), 10);

            if ($prec < 0) {
                Math::GMPq::Rmpq_div($n, $n, $p);
            }
            else {
                Math::GMPq::Rmpq_mul($n, $n, $p);
            }

            state $half = do {
                my $q = Math::GMPq::Rmpq_init_nobless();
                Math::GMPq::Rmpq_set_ui($q, 1, 2);
                $q;
            };

            my $z = Math::GMPz::Rmpz_init();
            Math::GMPq::Rmpq_add($n, $n, $half);
            Math::GMPz::Rmpz_set_q($z, $n);

            # Too much rounding... Give up and return an MPFR stringified number.
            !Math::GMPz::Rmpz_sgn($z) && $PREC >= 2 && do {
                my $mpfr = Math::MPFR::Rmpfr_init2($PREC);
                Math::MPFR::Rmpfr_set_q($mpfr, $x, $ROUND);
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

            my $num = Math::GMPz::Rmpz_init();
            my $den = Math::GMPz::Rmpz_init();

            Math::GMPq::Rmpq_numref($num, $n);
            Math::GMPq::Rmpq_denref($den, $n);

            my @r;
            while (1) {
                Math::GMPz::Rmpz_div($z, $num, $den);
                push @r, Math::GMPz::Rmpz_get_str($z, 10);

                Math::GMPz::Rmpz_mul($z, $z, $den);
                Math::GMPz::Rmpz_sub($num, $num, $z);
                last if !Math::GMPz::Rmpz_sgn($num);

                my $s = -1;
                while (Math::GMPz::Rmpz_cmp($den, $num) > 0) {
                    Math::GMPz::Rmpz_mul_ui($num, $num, 10);
                    ++$s;
                }

                push(@r, '0' x $s) if ($s > 0);
            }

            return (($sgn < 0 ? "-" : '') . shift(@r) . (('.' . join('', @r)) =~ s/0+\z//r =~ s/\.\z//r));
        }

      Math_MPFR: {
            Math::MPFR::Rmpfr_number_p($x)
              || return (
                           Math::MPFR::Rmpfr_nan_p($x)   ? 'NaN'
                         : Math::MPFR::Rmpfr_sgn($x) < 0 ? '-Inf'
                         :                                 'Inf'
                        );

            # log(10)/log(2) =~ 3.3219280948873623
            my $digits = CORE::int($PREC) >> 2;
            my ($mantissa, $exponent) = Math::MPFR::Rmpfr_deref2($x, 10, $digits, $ROUND);

            my $sgn = '';
            if (substr($mantissa, 0, 1) eq '-') {
                $sgn = substr($mantissa, 0, 1, '');
            }

            $mantissa =~ /[^0]/ or return '0';

            if (CORE::abs($exponent) < CORE::length($mantissa)) {

                if ($exponent > 0) {
                    substr($mantissa, $exponent, 0, '.');
                }
                else {
                    substr($mantissa, 0, 0, '0.' . ('0' x CORE::abs($exponent)));
                }

                $mantissa = reverse($mantissa);
                $mantissa =~ s/^0+//;
                $mantissa =~ s/^\.//;
                $mantissa = reverse($mantissa);

                return ($sgn . $mantissa);
            }

            if (CORE::length($mantissa) > 1) {
                substr($mantissa, 1, 0, '.');
            }

            return ($sgn . $mantissa . 'e' . ($exponent - 1));
        }

      Math_MPC: {
            my $fr = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            Math::MPC::RMPC_RE($fr, $x);
            my $re = __SUB__->($fr);

            Math::MPC::RMPC_IM($fr, $x);
            my $im = __SUB__->($fr);

            if ($im eq '0' or $im eq '-0') {
                return $re;
            }

            my $sign = '+';

            if (substr($im, 0, 1) eq '-') {
                $sign = '-';
                substr($im, 0, 1, '');
            }

            $im = '' if $im eq '1';
            return ($re eq '0' ? $sign eq '+' ? "${im}i" : "$sign${im}i" : "$re$sign${im}i");
        }
    }

    sub get_value {
        (@_) = (${$_[0]});
        goto &__stringify__;
    }

    #
    ## Public conversion methods
    #

    sub int {
        my ($x) = @_;
        ref($$x) eq 'Math::GMPz' ? $x : bless \(_any2mpz($$x) // (goto &nan));
    }

    *trunc = \&int;

    sub rat {
        my ($x) = @_;
        ref($$x) eq 'Math::GMPq' ? $x : bless \(_any2mpq($$x) // (goto &nan));
    }

    sub float {
        my ($x) = @_;
        ref($$x) eq 'Math::MPFR' ? $x : bless \_any2mpfr($$x);
    }

    sub complex {
        my ($x) = @_;
        ref($$x) eq 'Math::MPC' ? $x : bless \_any2mpc($$x);
    }

    sub pair {
        my ($x, $y) = @_;
        Sidef::Types::Number::Complex->new($x, $y);
    }

    sub __norm__ {
        my ($x) = @_;

        goto(ref($x) =~ tr/:/_/rs);

      Math_MPC: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::Rmpc_norm($r, $x, $ROUND);
            return $r;
        }

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_sqr($r, $x, $ROUND);
            return $r;
        }

      Math_GMPz: {
            my $r = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_mul($r, $x, $x);
            return $r;
        }

      Math_GMPq: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_mul($r, $x, $x);
            return $r;
        }
    }

    sub norm {
        my ($x) = @_;
        bless \__norm__($$x);
    }

    sub conj {
        my ($x) = @_;
        ref($$x) eq 'Math::MPC' or return $x;
        my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
        Math::MPC::Rmpc_conj($r, $$x, $ROUND);
        bless \$r;
    }

    *conjug    = \&conj;
    *conjugate = \&conj;

    sub real {
        my ($x) = @_;

        if (ref($$x) eq 'Math::MPC') {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::RMPC_RE($r, $$x);
            bless \$r;
        }
        else {
            $x;
        }
    }

    *re = \&real;

    sub imag {
        my ($x) = @_;

        if (ref($$x) eq 'Math::MPC') {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::RMPC_IM($r, $$x);
            bless \$r;
        }
        else {
            ZERO;
        }
    }

    *im        = \&imag;
    *imaginary = \&imag;

    sub reals {
        ($_[0]->real, $_[0]->imag);
    }

    #
    ## CONSTANTS
    #

    sub pi {
        my $pi = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_const_pi($pi, $ROUND);
        bless \$pi;
    }

    sub tau {
        my $tau = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_const_pi($tau, $ROUND);
        Math::MPFR::Rmpfr_mul_ui($tau, $tau, 2, $ROUND);
        bless \$tau;
    }

    sub ln2 {
        my $ln2 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_const_log2($ln2, $ROUND);
        bless \$ln2;
    }

    sub euler {
        my $euler = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_const_euler($euler, $ROUND);
        bless \$euler;
    }

    *Y = \&euler;

    sub catalan {
        my $catalan = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_const_catalan($catalan, $ROUND);
        bless \$catalan;
    }

    *C = \&catalan;

    sub i {
        my ($x) = @_;

        state $i = do {
            my $c = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_ui_ui($c, 0, 1, $ROUND);
            $c;
        };

        if (ref($x) eq __PACKAGE__) {
            bless \__mul__($i, $$x);
        }
        else {
            state $obj = bless \$i;
        }
    }

    sub e {
        state $one_f = (Math::MPFR::Rmpfr_init_set_ui_nobless(1, $ROUND))[0];
        my $e = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_exp($e, $one_f, $ROUND);
        bless \$e;
    }

    sub phi {
        state $five4_f = (Math::MPFR::Rmpfr_init_set_str_nobless("1.25", 10, $ROUND))[0];
        state $half_f  = (Math::MPFR::Rmpfr_init_set_str_nobless("0.5",  10, $ROUND))[0];

        my $phi = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_sqrt($phi, $five4_f, $ROUND);
        Math::MPFR::Rmpfr_add($phi, $phi, $half_f, $ROUND);

        bless \$phi;
    }

    sub _nan {
        state $nan = do {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_nan($r);
            $r;
        };
    }

    sub nan {
        state $nan = do {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_nan($r);
            bless \$r;
        };
    }

    sub _inf {
        state $inf = do {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_inf($r, 1);
            $r;
        };
    }

    sub inf {
        state $inf = do {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_inf($r, 1);
            bless \$r;
        };
    }

    sub _ninf {
        state $ninf = do {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_inf($r, -1);
            $r;
        };
    }

    sub ninf {
        state $ninf = do {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_inf($r, -1);
            bless \$r;
        };
    }

    sub _zero {
        state $zero = Math::GMPz::Rmpz_init_set_ui(0);
    }

    sub zero {
        state $zero = do {
            my $r = Math::GMPz::Rmpz_init_set_ui(0);
            bless \$r;
        };
    }

    sub _one {
        state $one = Math::GMPz::Rmpz_init_set_ui(1);
    }

    sub one {
        state $one = do {
            my $r = Math::GMPz::Rmpz_init_set_ui(1);
            bless \$r;
        };
    }

    sub _mone {
        state $mone = Math::GMPz::Rmpz_init_set_si(-1);
    }

    sub mone {
        state $mone = do {
            my $r = Math::GMPz::Rmpz_init_set_si(-1);
            bless \$r;
        };
    }

    sub __add__ {
        my ($x, $y) = @_;

        goto(join('__', ref($x), ref($y)) =~ tr/:/_/rs);

        #
        ## GMPz
        #
      Math_GMPz__Math_GMPz: {
            my $r = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_add($r, $x, $y);
            return $r;
        }

      Math_GMPz__Math_GMPq: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_add_z($r, $y, $x);
            return $r;
        }

      Math_GMPz__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_add_z($r, $y, $x, $ROUND);
            return $r;
        }

      Math_GMPz__Math_MPC: {
            my $c = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_z($c, $x, $ROUND);
            Math::MPC::Rmpc_add($c, $c, $y, $ROUND);
            return $c;
        }

        #
        ## GMPq
        #
      Math_GMPq__Math_GMPq: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_add($r, $x, $y);
            return $r;
        }

      Math_GMPq__Math_GMPz: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_add_z($r, $x, $y);
            return $r;
        }

      Math_GMPq__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_add_q($r, $y, $x, $ROUND);
            return $r;
        }

      Math_GMPq__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_q($r, $x, $ROUND);
            Math::MPC::Rmpc_add($r, $r, $y, $ROUND);
            return $r;
        }

        #
        ## MPFR
        #
      Math_MPFR__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_add($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_GMPq: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_add_q($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_GMPz: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_add_z($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_add_fr($r, $y, $x, $ROUND);
            return $r;
        }

        #
        ## MPC
        #
      Math_MPC__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_add($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_MPFR: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_add_fr($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_GMPz: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_z($r, $y, $ROUND);
            Math::MPC::Rmpc_add($r, $r, $x, $ROUND);
            return $r;
        }

      Math_MPC__Math_GMPq: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_q($r, $y, $ROUND);
            Math::MPC::Rmpc_add($r, $r, $x, $ROUND);
            return $r;
        }
    }

    sub add {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__add__($$x, $$y);
    }

    sub __sub__ {
        my ($x, $y) = @_;

        goto(join('__', ref($x), ref($y)) =~ tr/:/_/rs);

        #
        ## GMPq
        #
      Math_GMPq__Math_GMPq: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_sub($r, $x, $y);
            return $r;
        }

      Math_GMPq__Math_GMPz: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_sub_z($r, $x, $y);
            return $r;
        }

      Math_GMPq__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_q($r, $x, $ROUND);
            Math::MPFR::Rmpfr_sub($r, $r, $y, $ROUND);
            return $r;
        }

      Math_GMPq__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_q($r, $x, $ROUND);
            Math::MPC::Rmpc_sub($r, $r, $y, $ROUND);
            return $r;
        }

        #
        ## GMPz
        #
      Math_GMPz__Math_GMPz: {
            my $r = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_sub($r, $x, $y);
            return $r;
        }

      Math_GMPz__Math_GMPq: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_z_sub($r, $x, $y);
            return $r;
        }

      Math_GMPz__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_z($r, $x, $ROUND);
            Math::MPFR::Rmpfr_sub($r, $r, $y, $ROUND);
            return $r;
        }

      Math_GMPz__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_z($r, $x, $ROUND);
            Math::MPC::Rmpc_sub($r, $r, $y, $ROUND);
            return $r;
        }

        #
        ## MPFR
        #
      Math_MPFR__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_sub($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_GMPq: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_sub_q($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_GMPz: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_sub_z($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_fr($r, $x, $ROUND);
            Math::MPC::Rmpc_sub($r, $r, $y, $ROUND);
            return $r;
        }

        #
        ## MPC
        #
      Math_MPC__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_sub($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_MPFR: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_fr($r, $y, $ROUND);
            Math::MPC::Rmpc_sub($r, $x, $r, $ROUND);
            return $r;
        }

      Math_MPC__Math_GMPz: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_z($r, $y, $ROUND);
            Math::MPC::Rmpc_sub($r, $x, $r, $ROUND);
            return $r;
        }

      Math_MPC__Math_GMPq: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_q($r, $y, $ROUND);
            Math::MPC::Rmpc_sub($r, $x, $r, $ROUND);
            return $r;
        }
    }

    sub sub {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__sub__($$x, $$y);
    }

    sub __mul__ {
        my ($x, $y) = @_;

        goto(join('__', ref($x), ref($y)) =~ tr/:/_/rs);

        #
        ## GMPq
        #
      Math_GMPq__Math_GMPq: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_mul($r, $x, $y);
            return $r;
        }

      Math_GMPq__Math_GMPz: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_mul_z($r, $x, $y);
            return $r;
        }

      Math_GMPq__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_mul_q($r, $y, $x, $ROUND);
            return $r;
        }

      Math_GMPq__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_q($r, $x, $ROUND);
            Math::MPC::Rmpc_mul($r, $r, $y, $ROUND);
            return $r;
        }

        #
        ## GMPz
        #
      Math_GMPz__Math_GMPz: {
            my $r = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_mul($r, $x, $y);
            return $r;
        }

      Math_GMPz__Math_GMPq: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_mul_z($r, $y, $x);
            return $r;
        }

      Math_GMPz__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_mul_z($r, $y, $x, $ROUND);
            return $r;
        }

      Math_GMPz__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_z($r, $x, $ROUND);
            Math::MPC::Rmpc_mul($r, $r, $y, $ROUND);
            return $r;
        }

        #
        ## MPFR
        #
      Math_MPFR__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_mul($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_GMPq: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_mul_q($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_GMPz: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_mul_z($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_mul_fr($r, $y, $x, $ROUND);
            return $r;
        }

        #
        ## MPC
        #
      Math_MPC__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_mul($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_MPFR: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_mul_fr($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_GMPz: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_z($r, $y, $ROUND);
            Math::MPC::Rmpc_mul($r, $r, $x, $ROUND);
            return $r;
        }

      Math_MPC__Math_GMPq: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_q($r, $y, $ROUND);
            Math::MPC::Rmpc_mul($r, $r, $x, $ROUND);
            return $r;
        }
    }

    sub mul {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__mul__($$x, $$y);
    }

    sub __div__ {
        my ($x, $y) = @_;

        goto(join('__', ref($x), ref($y)) =~ tr/:/_/rs);

        #
        ## GMPq
        #
      Math_GMPq__Math_GMPq: {

            # Check for division by zero
            Math::GMPq::Rmpq_sgn($y) || do {
                $x = _mpq2mpfr($x);
                goto Math_MPFR__Math_GMPq;
            };

            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_div($r, $x, $y);
            return $r;
        }

      Math_GMPq__Math_GMPz: {

            # Check for division by zero
            Math::GMPz::Rmpz_sgn($y) || do {
                $x = _mpq2mpfr($x);
                goto Math_MPFR__Math_GMPz;
            };

            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_div_z($r, $x, $y);
            return $r;
        }

      Math_GMPq__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_q($r, $x, $ROUND);
            Math::MPFR::Rmpfr_div($r, $r, $y, $ROUND);
            return $r;
        }

      Math_GMPq__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_q($r, $x, $ROUND);
            Math::MPC::Rmpc_div($r, $r, $y, $ROUND);
            return $r;
        }

        #
        ## GMPz
        #
      Math_GMPz__Math_GMPz: {

            # Check for division by zero
            Math::GMPz::Rmpz_sgn($y) || do {
                $x = _mpz2mpfr($x);
                goto Math_MPFR__Math_GMPz;
            };

            # Check for exact divisibility
            if (Math::GMPz::Rmpz_divisible_p($x, $y)) {
                my $r = Math::GMPz::Rmpz_init();
                Math::GMPz::Rmpz_divexact($r, $x, $y);
                return $r;
            }

            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_num($r, $x);
            Math::GMPq::Rmpq_set_den($r, $y);
            Math::GMPq::Rmpq_canonicalize($r);
            return $r;
        }

      Math_GMPz__Math_GMPq: {

            # Check for division by zero
            Math::GMPq::Rmpq_sgn($y) || do {
                $x = _mpz2mpfr($x);
                goto Math_MPFR__Math_GMPq;
            };

            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_z_div($r, $x, $y);
            return $r;
        }

      Math_GMPz__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_z($r, $x, $ROUND);
            Math::MPFR::Rmpfr_div($r, $r, $y, $ROUND);
            return $r;
        }

      Math_GMPz__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_z($r, $x, $ROUND);
            Math::MPC::Rmpc_div($r, $r, $y, $ROUND);
            return $r;
        }

        #
        ## MPFR
        #
      Math_MPFR__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_div($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_GMPq: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_div_q($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_GMPz: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_div_z($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_fr($r, $x, $ROUND);
            Math::MPC::Rmpc_div($r, $r, $y, $ROUND);
            return $r;
        }

        #
        ## MPC
        #
      Math_MPC__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_div($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_MPFR: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_div_fr($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_GMPz: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_z($r, $y, $ROUND);
            Math::MPC::Rmpc_div($r, $x, $r, $ROUND);
            return $r;
        }

      Math_MPC__Math_GMPq: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_q($r, $y, $ROUND);
            Math::MPC::Rmpc_div($r, $x, $r, $ROUND);
            return $r;
        }
    }

    sub div {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__div__($$x, $$y);
    }

    #
    ## Integer operations
    #

    sub iadd {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // (goto &nan);
        $y = _any2mpz($$y) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_add($r, $x, $y);
        bless \$r;
    }

    sub isub {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // (goto &nan);
        $y = _any2mpz($$y) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_sub($r, $x, $y);
        bless \$r;
    }

    sub imul {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // (goto &nan);
        $y = _any2mpz($$y) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_mul($r, $x, $y);
        bless \$r;
    }

    sub idiv {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // (goto &nan);
        $y = _any2mpz($$y) // (goto &nan);

        # Detect division by zero
        if (!Math::GMPz::Rmpz_sgn($y)) {
            my $sign = Math::GMPz::Rmpz_sgn($x);

            if ($sign == 0) {    # 0/0
                goto &nan;
            }
            elsif ($sign > 0) {    # x/0 where: x > 0
                goto &inf;
            }
            else {                 # x/0 where: x < 0
                goto &ninf;
            }
        }

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_tdiv_q($r, $x, $y);
        bless \$r;
    }

    sub neg {
        my ($x) = @_;

        $x = $$x;
        goto(ref($x) =~ tr/:/_/rs);

      Math_GMPz: {
            my $r = Math::GMPz::Rmpz_init_set($x);
            Math::GMPz::Rmpz_neg($r, $r);
            return bless \$r;
        }

      Math_GMPq: {
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_neg($r, $x);
            return bless \$r;
        }

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_neg($r, $x, $ROUND);
            return bless \$r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_neg($r, $x, $ROUND);
            return bless \$r;
        }
    }

    sub abs {
        my ($x) = @_;

        $x = $$x;
        goto(ref($x) =~ tr/:/_/rs);

      Math_GMPz: {
            Math::GMPz::Rmpz_sgn($x) >= 0 and return $_[0];
            my $r = Math::GMPz::Rmpz_init_set($x);
            Math::GMPz::Rmpz_abs($r, $r);
            return bless \$r;
        }

      Math_GMPq: {
            Math::GMPq::Rmpq_sgn($x) >= 0 and return $_[0];
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_abs($r, $x);
            return bless \$r;
        }

      Math_MPFR: {
            Math::MPFR::Rmpfr_sgn($x) >= 0 and return $_[0];
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_abs($r, $x, $ROUND);
            return bless \$r;
        }

      Math_MPC: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::Rmpc_abs($r, $x, $ROUND);
            return bless \$r;
        }
    }

    sub __inv__ {
        my ($x) = @_;

        goto(ref($x) =~ tr/:/_/rs);

      Math_GMPq: {

            # Check for division by zero
            Math::GMPq::Rmpq_sgn($x) || do {
                $x = _mpq2mpfr($x);
                goto Math_MPFR;
            };

            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_inv($r, $x);
            return $r;
        }

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_ui_div($r, 1, $x, $ROUND);
            return $r;
        }

      Math_GMPz: {

            # Check for division by zero
            Math::GMPz::Rmpz_sgn($x) || do {
                $x = _mpz2mpfr($x);
                goto Math_MPFR;
            };

            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set_z($r, $x);
            Math::GMPq::Rmpq_inv($r, $r);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_ui_div($r, 1, $x, $ROUND);
            return $r;
        }
    }

    sub inv {
        my ($x) = @_;
        bless \__inv__($$x);
    }

    sub sqr {
        my ($x) = @_;
        bless \__mul__($$x, $$x);
    }

    sub __sqrt__ {
        my ($x) = @_;

        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {

            # Complex for x < 0
            if (Math::MPFR::Rmpfr_sgn($x) < 0) {
                $x = _mpfr2mpc($x);
                goto Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_sqrt($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_sqrt($r, $x, $ROUND);
            return $r;
        }
    }

    sub sqrt {
        my ($x) = @_;
        bless \__sqrt__(_any2mpfr_mpc($$x));
    }

    sub __cbrt__ {
        my ($x) = @_;

        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {

            # Complex for x < 0
            if (Math::MPFR::Rmpfr_sgn($x) < 0) {
                $x = _mpfr2mpc($x);
                goto Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_cbrt($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            state $three_inv = do {
                my $r = Math::MPC::Rmpc_init2_nobless(CORE::int($PREC));
                Math::MPC::Rmpc_set_ui($r, 3, $ROUND);
                Math::MPC::Rmpc_ui_div($r, 1, $r, $ROUND);
                $r;
            };

            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_pow($r, $x, $three_inv, $ROUND);
            return $r;
        }
    }

    sub cbrt {
        my ($x) = @_;
        bless \__cbrt__(_any2mpfr_mpc($$x));
    }

    sub __iroot__ {
        my ($x, $y) = @_;

        # $x is a Math::GMPz object
        # $y is a signed integer

        if ($y == 0) {
            Math::GMPz::Rmpz_sgn($x) || return $x;    # 0^Inf = 0

            # 1^Inf = 1 ; (-1)^Inf = 1
            if (Math::GMPz::Rmpz_cmpabs_ui($x, 1) == 0) {
                return Math::GMPz::Rmpz_init_set_ui(1);
            }

            goto &_inf;
        }
        elsif ($y < 0) {
            my $sign = Math::GMPz::Rmpz_sgn($x) || goto &_inf;    # 1 / 0^k = Inf
            Math::GMPz::Rmpz_cmp_ui($x, 1) || return $x;          # 1 / 1^k = 1

            if ($sign < 0) {
                goto &_nan;
            }

            return Math::GMPz::Rmpz_init_set_ui(0);
        }
        elsif ($y % 2 == 0 and Math::GMPz::Rmpz_sgn($x) < 0) {
            goto &_nan;
        }

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_root($r, $x, $y);
        $r;
    }

    sub iroot {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__iroot__(_any2mpz($$x) // (goto &nan), _any2si($$y) // (goto &nan));
    }

    sub isqrt {
        my ($x) = @_;

        $x = _any2mpz($$x) // goto &nan;
        Math::GMPz::Rmpz_sgn($x) < 0 and goto &nan;

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_sqrt($r, $x);
        bless \$r;
    }

    sub icbrt {
        my ($x) = @_;
        bless \__iroot__(_any2mpz($$x) // (goto &nan), 3);
    }

    sub isqrtrem {
        my ($x) = @_;

        $x = _any2mpz($$x) // goto &nan;

        Math::GMPz::Rmpz_sgn($x) < 0
          and return ((nan()) x 2);

        my $r = Math::GMPz::Rmpz_init();
        my $s = Math::GMPz::Rmpz_init();

        Math::GMPz::Rmpz_sqrtrem($r, $s, $x);
        ((bless \$r), (bless \$s));
    }

    sub irootrem {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // goto &nan;
        $y = _any2si($$y)  // goto &nan;

        if ($y == 0) {
            Math::GMPz::Rmpz_sgn($x) || return (ZERO, MONE);    # 0^Inf = 0

            if (Math::GMPz::Rmpz_cmpabs_ui($x, 1) == 0) {       # 1^Inf = 1 ; (-1)^Inf = 1
                return (ONE, bless \__dec__($x));
            }

            return (inf(), bless \__dec__($x));
        }
        elsif ($y < 0) {
            my $sign = Math::GMPz::Rmpz_sgn($x) || return (inf(), ZERO);    # 1 / 0^k = Inf
            Math::GMPz::Rmpz_cmp_ui($x, 1) == 0 and return (ONE, ZERO);     # 1 / 1^k = 1
            return ($sign < 0 ? (nan(), nan()) : (ZERO, ninf()));
        }
        elsif ($y % 2 == 0 and Math::GMPz::Rmpz_sgn($x) < 0) {
            return (nan(), nan());
        }

        my $r = Math::GMPz::Rmpz_init();
        my $s = Math::GMPz::Rmpz_init();

        Math::GMPz::Rmpz_rootrem($r, $s, $x, $y);
        ((bless \$r), (bless \$s));
    }

    sub __pow__ {
        my ($x, $y) = @_;

        goto(join('__', ref($x), ref($y) || 'Scalar') =~ tr/:/_/rs);

        #
        ## GMPq
        #
      Math_GMPq__Scalar: {

            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_pow_ui($r, $x, CORE::abs($y));

            if ($y < 0) {
                Math::GMPq::Rmpq_sgn($r) || goto &_inf;
                Math::GMPq::Rmpq_inv($r, $r);
            }

            return $r;
        }

      Math_GMPq__Math_GMPq: {

            # Integer power
            if (Math::GMPq::Rmpq_integer_p($y)) {
                $y = Math::GMPq::Rmpq_get_d($y);
                goto Math_GMPq__Scalar;
            }

            # (-x)^(a/b) is a complex number
            elsif (Math::GMPq::Rmpq_sgn($x) < 0) {
                ($x, $y) = (_mpq2mpc($x), _mpq2mpc($y));
                goto Math_MPC__Math_MPC;
            }

            ($x, $y) = (_mpq2mpfr($x), _mpq2mpfr($y));
            goto Math_MPFR__Math_MPFR;
        }

      Math_GMPq__Math_GMPz: {
            $y = Math::GMPz::Rmpz_get_d($y);
            goto Math_GMPq__Scalar;
        }

      Math_GMPq__Math_MPFR: {
            $x = _mpq2mpfr($x);
            goto Math_MPFR__Math_MPFR;
        }

      Math_GMPq__Math_MPC: {
            $x = _mpq2mpc($x);
            goto Math_MPC__Math_MPC;
        }

        #
        ## GMPz
        #
      Math_GMPz__Scalar: {

            my $r = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_pow_ui($r, $x, CORE::abs($y));

            if ($y < 0) {
                Math::GMPz::Rmpz_sgn($r) || goto &_inf;

                my $q = Math::GMPq::Rmpq_init();
                Math::GMPq::Rmpq_set_z($q, $r);
                Math::GMPq::Rmpq_inv($q, $q);
                return $q;
            }

            return $r;
        }

      Math_GMPz__Math_GMPz: {
            $y = Math::GMPz::Rmpz_get_d($y);
            goto Math_GMPz__Scalar;
        }

      Math_GMPz__Math_GMPq: {
            if (Math::GMPq::Rmpq_integer_p($y)) {
                $y = Math::GMPq::Rmpq_get_d($y);
                goto Math_GMPz__Scalar;
            }

            ($x, $y) = (_mpz2mpfr($x), _mpq2mpfr($y));
            goto Math_MPFR__Math_MPFR;
        }

      Math_GMPz__Math_MPFR: {
            $x = _mpz2mpfr($x);
            goto Math_MPFR__Math_MPFR;
        }

      Math_GMPz__Math_MPC: {
            $x = _mpz2mpc($x);
            goto Math_MPC__Math_MPC;
        }

        #
        ## MPFR
        #
      Math_MPFR__Math_MPFR: {
            if (    Math::MPFR::Rmpfr_sgn($x) < 0
                and !Math::MPFR::Rmpfr_integer_p($y)
                and Math::MPFR::Rmpfr_number_p($y)) {
                $x = _mpfr2mpc($x);
                goto Math_MPC__Math_MPFR;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_pow($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Scalar: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            $y < 0
              ? Math::MPFR::Rmpfr_pow_si($r, $x, $y, $ROUND)
              : Math::MPFR::Rmpfr_pow_ui($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_GMPq: {
            $y = _mpq2mpfr($y);
            goto Math_MPFR__Math_MPFR;
        }

      Math_MPFR__Math_GMPz: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_pow_z($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_MPC: {
            $x = _mpfr2mpc($x);
            goto Math_MPC__Math_MPC;
        }

        #
        ## MPC
        #
      Math_MPC__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_pow($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Scalar: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            $y < 0
              ? Math::MPC::Rmpc_pow_si($r, $x, $y, $ROUND)
              : Math::MPC::Rmpc_pow_ui($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_MPFR: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_pow_fr($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_GMPz: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_pow_z($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_GMPq: {
            $y = _mpq2mpc($y);
            goto Math_MPC__Math_MPC;
        }
    }

    sub root {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__pow__($$x, __inv__($$y));
    }

    sub pow {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__pow__($$x, $$y);
    }

    sub ipow {
        my ($x, $y) = @_;
        _valid(\$y);

        $x = _any2mpz($$x) // goto &nan;
        $y = _any2si($$y)  // goto &nan;

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_pow_ui($r, $x, CORE::abs($y));

        if ($y < 0) {
            Math::GMPz::Rmpz_sgn($r) || goto &inf;    # 0^(-y) = Inf
            state $ONE_Z = Math::GMPz::Rmpz_init_set_ui_nobless(1);
            Math::GMPz::Rmpz_tdiv_q($r, $ONE_Z, $r);
        }

        bless \$r;
    }

    sub __log2__ {
        my ($x) = @_;

        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {

            # Complex for x < 0
            if (Math::MPFR::Rmpfr_sgn($x) < 0) {
                $x = _mpfr2mpc($x);
                goto Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_log2($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $ln2 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_const_log2($ln2, $ROUND);
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_log($r, $x, $ROUND);
            Math::MPC::Rmpc_div_fr($r, $r, $ln2, $ROUND);
            return $r;
        }
    }

    sub __log10__ {
        my ($x) = @_;

        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {

            # Complex for x < 0
            if (Math::MPFR::Rmpfr_sgn($x) < 0) {
                $x = _mpfr2mpc($x);
                goto Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_log10($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            state $MPC_VERSION = Math::MPC::MPC_VERSION();

            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));

            if ($MPC_VERSION >= 65536) {    # available only in mpc>=1.0.0
                Math::MPC::Rmpc_log10($r, $x, $ROUND);
            }
            else {
                my $ln10 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
                Math::MPFR::Rmpfr_set_ui($ln10, 10, $ROUND);
                Math::MPFR::Rmpfr_log($ln10, $ln10, $ROUND);
                Math::MPC::Rmpc_log($r, $x, $ROUND);
                Math::MPC::Rmpc_div_fr($r, $r, $ln10, $ROUND);
            }

            return $r;
        }
    }

    sub __log__ {
        my ($x) = @_;

        goto(ref($x) =~ tr/:/_/rs);

        #
        ## MPFR
        #
      Math_MPFR: {

            # Complex for x < 0
            if (Math::MPFR::Rmpfr_sgn($x) < 0) {
                $x = _mpfr2mpc($x);
                goto Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_log($r, $x, $ROUND);
            return $r;
        }

        #
        ## MPC
        #
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_log($r, $x, $ROUND);
            return $r;
        }
    }

    sub log {
        my ($x, $y) = @_;

        if (defined($y)) {
            _valid(\$y);
            bless \__div__(__log__(_any2mpfr_mpc($$x)), __log__(_any2mpfr_mpc($$y)));
        }
        else {
            bless \__log__(_any2mpfr_mpc($$x));
        }
    }

    sub ln {
        my ($x) = @_;
        bless \__log__(_any2mpfr_mpc($$x));
    }

    sub log2 {
        my ($x) = @_;
        bless \__log2__(_any2mpfr_mpc($$x));
    }

    sub log10 {
        my ($x) = @_;
        bless \__log10__(_any2mpfr_mpc($$x));
    }

    sub __ilog__ {
        my ($x, $y) = @_;

        # ilog(x, y <= 1) = NaN
        Math::GMPz::Rmpz_cmp_ui($y, 1) <= 0 and goto &_nan;

        # ilog(x <= 0, y) = NaN
        Math::GMPz::Rmpz_sgn($x) <= 0 and goto &_nan;

        # Return faster for y <= 62
        if (Math::GMPz::Rmpz_cmp_ui($y, 62) <= 0) {

            $y = Math::GMPz::Rmpz_get_ui($y);

            my $t = Math::GMPz::Rmpz_init();
            my $e = (Math::GMPz::Rmpz_sizeinbase($x, $y) || goto &_nan) - 1;

            if ($e > 0) {
                Math::GMPz::Rmpz_ui_pow_ui($t, $y, $e);
                Math::GMPz::Rmpz_cmp($t, $x) > 0 and --$e;
            }

            Math::GMPz::Rmpz_set_ui($t, $e);
            return $t;
        }

        my $e = 0;
        my $t = Math::GMPz::Rmpz_init();

        state $round_z = Math::MPFR::MPFR_RNDZ();

        my $logx = Math::MPFR::Rmpfr_init2(92);
        my $logy = Math::MPFR::Rmpfr_init2(92);

        Math::MPFR::Rmpfr_set_z($logx, $x, $round_z);
        Math::MPFR::Rmpfr_set_z($logy, $y, $round_z);

        Math::MPFR::Rmpfr_log($logx, $logx, $round_z);
        Math::MPFR::Rmpfr_log($logy, $logy, $round_z);

        Math::MPFR::Rmpfr_div($logx, $logx, $logy, $round_z);

        if (Math::MPFR::Rmpfr_fits_ulong_p($logx, $round_z)) {
            $e = Math::MPFR::Rmpfr_get_ui($logx, $round_z) - 1;
            Math::GMPz::Rmpz_pow_ui($t, $y, $e + 1);
        }
        else {
            Math::GMPz::Rmpz_set($t, $y);
        }

        for (; Math::GMPz::Rmpz_cmp($t, $x) <= 0 ; Math::GMPz::Rmpz_mul($t, $t, $y)) {
            ++$e;
        }

        Math::GMPz::Rmpz_set_ui($t, $e);
        $t;
    }

    sub ilog {
        my ($x, $y) = @_;

        if (defined($y)) {
            _valid(\$y);
            bless \__ilog__((_any2mpz($$x) // goto &nan), (_any2mpz($$y) // goto &nan));
        }
        else {
            bless \(_any2mpz(__log__(_any2mpfr_mpc($$x))) // goto &nan);
        }
    }

    sub ilog2 {
        my ($x) = @_;
        state $two = Math::GMPz::Rmpz_init_set_ui(2);
        bless \__ilog__((_any2mpz($$x) // goto &nan), $two);
    }

    sub ilog10 {
        my ($x) = @_;
        state $ten = Math::GMPz::Rmpz_init_set_ui(10);
        bless \__ilog__((_any2mpz($$x) // goto &nan), $ten);
    }

    sub __lgrt__ {
        my ($c) = @_;

        $PREC = CORE::int($PREC) if ref($PREC);

        my $p = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_str($p, '1e-' . CORE::int($PREC >> 2), 10, $ROUND);

        goto(ref($c) =~ tr/:/_/rs);

      Math_MPFR: {

            # Return a complex number for x < e^(-1/e)
            if (Math::MPFR::Rmpfr_cmp_d($c, CORE::exp(-1 / CORE::exp(1))) < 0) {
                $c = _mpfr2mpc($c);
                goto Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2($PREC);
            Math::MPFR::Rmpfr_log($r, $c, $ROUND);

            Math::MPFR::Rmpfr_set_ui((my $x = Math::MPFR::Rmpfr_init2($PREC)), 1, $ROUND);
            Math::MPFR::Rmpfr_set_ui((my $y = Math::MPFR::Rmpfr_init2($PREC)), 0, $ROUND);

            my $count = 0;
            my $tmp   = Math::MPFR::Rmpfr_init2($PREC);

            while (1) {
                Math::MPFR::Rmpfr_sub($tmp, $x, $y, $ROUND);
                Math::MPFR::Rmpfr_cmpabs($tmp, $p) <= 0 and last;

                Math::MPFR::Rmpfr_set($y, $x, $ROUND);

                Math::MPFR::Rmpfr_log($tmp, $x, $ROUND);
                Math::MPFR::Rmpfr_add_ui($tmp, $tmp, 1, $ROUND);

                Math::MPFR::Rmpfr_add($x, $x, $r, $ROUND);
                Math::MPFR::Rmpfr_div($x, $x, $tmp, $ROUND);
                last if ++$count > $PREC;
            }

            return $x;
        }

      Math_MPC: {
            my $d = Math::MPC::Rmpc_init2($PREC);
            Math::MPC::Rmpc_log($d, $c, $ROUND);

            my $x = Math::MPC::Rmpc_init2($PREC);
            Math::MPC::Rmpc_sqr($x, $c, $ROUND);
            Math::MPC::Rmpc_add_ui($x, $x, 1, $ROUND);
            Math::MPC::Rmpc_log($x, $x, $ROUND);

            my $y = Math::MPC::Rmpc_init2($PREC);
            Math::MPC::Rmpc_set_ui($y, 0, $ROUND);

            my $tmp = Math::MPC::Rmpc_init2($PREC);
            my $abs = Math::MPFR::Rmpfr_init2($PREC);

            my $count = 0;
            while (1) {
                Math::MPC::Rmpc_sub($tmp, $x, $y, $ROUND);

                Math::MPC::Rmpc_abs($abs, $tmp, $ROUND);
                Math::MPFR::Rmpfr_cmp($abs, $p) <= 0 and last;

                Math::MPC::Rmpc_set($y, $x, $ROUND);

                Math::MPC::Rmpc_log($tmp, $x, $ROUND);
                Math::MPC::Rmpc_add_ui($tmp, $tmp, 1, $ROUND);

                Math::MPC::Rmpc_add($x, $x, $d, $ROUND);
                Math::MPC::Rmpc_div($x, $x, $tmp, $ROUND);
                last if ++$count > $PREC;
            }

            return $x;
        }
    }

    sub lgrt {
        my ($x) = @_;
        bless \__lgrt__(_any2mpfr_mpc($$x));
    }

    sub __LambertW__ {
        my ($x) = @_;

        $PREC = CORE::int($PREC) if ref($PREC);

        my $p = Math::MPFR::Rmpfr_init2($PREC);
        Math::MPFR::Rmpfr_set_str($p, '1e-' . CORE::int($PREC >> 2), 10, $ROUND);

        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {

            # Return a complex number for x < -1/e
            if (Math::MPFR::Rmpfr_cmp_d($x, -1 / CORE::exp(1)) < 0) {
                $x = _mpfr2mpc($x);
                goto Math_MPC;
            }

            Math::MPFR::Rmpfr_set_ui((my $r = Math::MPFR::Rmpfr_init2($PREC)), 1, $ROUND);
            Math::MPFR::Rmpfr_set_ui((my $y = Math::MPFR::Rmpfr_init2($PREC)), 0, $ROUND);

            my $count = 0;
            my $tmp   = Math::MPFR::Rmpfr_init2($PREC);

            while (1) {
                Math::MPFR::Rmpfr_sub($tmp, $r, $y, $ROUND);
                Math::MPFR::Rmpfr_cmpabs($tmp, $p) <= 0 and last;

                Math::MPFR::Rmpfr_set($y, $r, $ROUND);

                Math::MPFR::Rmpfr_log($tmp, $r, $ROUND);
                Math::MPFR::Rmpfr_add_ui($tmp, $tmp, 1, $ROUND);

                Math::MPFR::Rmpfr_add($r, $r, $x, $ROUND);
                Math::MPFR::Rmpfr_div($r, $r, $tmp, $ROUND);
                last if ++$count > $PREC;
            }

            Math::MPFR::Rmpfr_log($r, $r, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2($PREC);
            Math::MPC::Rmpc_sqrt($r, $x, $ROUND);
            Math::MPC::Rmpc_add_ui($r, $r, 1, $ROUND);

            my $y = Math::MPC::Rmpc_init2($PREC);
            Math::MPC::Rmpc_set_ui($y, 0, $ROUND);

            my $tmp = Math::MPC::Rmpc_init2($PREC);
            my $abs = Math::MPFR::Rmpfr_init2($PREC);

            my $count = 0;
            while (1) {
                Math::MPC::Rmpc_sub($tmp, $r, $y, $ROUND);

                Math::MPC::Rmpc_abs($abs, $tmp, $ROUND);
                Math::MPFR::Rmpfr_cmp($abs, $p) <= 0 and last;

                Math::MPC::Rmpc_set($y, $r, $ROUND);

                Math::MPC::Rmpc_log($tmp, $r, $ROUND);
                Math::MPC::Rmpc_add_ui($tmp, $tmp, 1, $ROUND);

                Math::MPC::Rmpc_add($r, $r, $x, $ROUND);
                Math::MPC::Rmpc_div($r, $r, $tmp, $ROUND);
                last if ++$count > $PREC;
            }

            Math::MPC::Rmpc_log($r, $r, $ROUND);
            return $r;
        }
    }

    sub lambert_w {
        my ($x) = @_;
        bless \__LambertW__(_any2mpfr_mpc($$x));
    }

    *LambertW = \&lambert_w;

    sub __exp__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_exp($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_exp($r, $x, $ROUND);
            return $r;
        }
    }

    sub exp {
        my ($x) = @_;
        bless \__exp__(_any2mpfr_mpc($$x));
    }

    sub exp2 {
        my ($x) = @_;
        state $base = Math::GMPz::Rmpz_init_set_ui(2);
        bless \__pow__($base, $$x);
    }

    sub exp10 {
        my ($x) = @_;
        state $base = Math::GMPz::Rmpz_init_set_ui(10);
        bless \__pow__($base, $$x);
    }

    #
    ## sin / sinh / asin / asinh
    #

    sub __sin__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_sin($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_sin($r, $x, $ROUND);
            return $r;
        }
    }

    sub sin {
        my ($x) = @_;
        bless \__sin__(_any2mpfr_mpc($$x));
    }

    sub __sinh__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_sinh($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_sinh($r, $x, $ROUND);
            return $r;
        }
    }

    sub sinh {
        my ($x) = @_;
        bless \__sinh__(_any2mpfr_mpc($$x));
    }

    sub __asin__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {

            # Return a complex number for x < -1 or x > 1
            if (   Math::MPFR::Rmpfr_cmp_ui($x, 1) > 0
                or Math::MPFR::Rmpfr_cmp_si($x, -1) < 0) {
                my $r = _mpfr2mpc($x);
                Math::MPC::Rmpc_asin($r, $r, $ROUND);
                return $r;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_asin($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_asin($r, $x, $ROUND);
            return $r;
        }
    }

    sub asin {
        my ($x) = @_;
        bless \__asin__(_any2mpfr_mpc($$x));
    }

    sub __asinh__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_asinh($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_asinh($r, $x, $ROUND);
            return $r;
        }
    }

    sub asinh {
        my ($x) = @_;
        bless \__asinh__(_any2mpfr_mpc($$x));
    }

    #
    ## cos / cosh / acos / acosh
    #

    sub __cos__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_cos($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_cos($r, $x, $ROUND);
            return $r;
        }
    }

    sub cos {
        my ($x) = @_;
        bless \__cos__(_any2mpfr_mpc($$x));
    }

    sub __cosh__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_cosh($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_cosh($r, $x, $ROUND);
            return $r;
        }
    }

    sub cosh {
        my ($x) = @_;
        bless \__cosh__(_any2mpfr_mpc($$x));
    }

    sub __acos__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {

            # Return a complex number for x < -1 or x > 1
            if (   Math::MPFR::Rmpfr_cmp_ui($x, 1) > 0
                or Math::MPFR::Rmpfr_cmp_si($x, -1) < 0) {
                my $r = _mpfr2mpc($x);
                Math::MPC::Rmpc_acos($r, $r, $ROUND);
                return $r;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_acos($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_acos($r, $x, $ROUND);
            return $r;
        }
    }

    sub acos {
        my ($x) = @_;
        bless \__acos__(_any2mpfr_mpc($$x));
    }

    sub __acosh__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {

            # Return a complex number for x < 1
            if (Math::MPFR::Rmpfr_cmp_ui($x, 1) < 0) {
                my $r = _mpfr2mpc($x);
                Math::MPC::Rmpc_acosh($r, $r, $ROUND);
                return $r;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_acosh($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_acosh($r, $x, $ROUND);
            return $r;
        }
    }

    sub acosh {
        my ($x) = @_;
        bless \__acosh__(_any2mpfr_mpc($$x));
    }

    #
    ## tan / tanh / atan / atanh
    #

    sub __tan__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_tan($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_tan($r, $x, $ROUND);
            return $r;
        }
    }

    sub tan {
        my ($x) = @_;
        bless \__tan__(_any2mpfr_mpc($$x));
    }

    sub __tanh__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_tanh($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_tanh($r, $x, $ROUND);
            return $r;
        }
    }

    sub tanh {
        my ($x) = @_;
        bless \__tanh__(_any2mpfr_mpc($$x));
    }

    sub __atan__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_atan($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_atan($r, $x, $ROUND);
            return $r;
        }
    }

    sub atan {
        my ($x) = @_;
        bless \__atan__(_any2mpfr_mpc($$x));
    }

    sub __atanh__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {

            # Return a complex number for x < -1 or x > 1
            if (   Math::MPFR::Rmpfr_cmp_ui($x, +1) > 0
                or Math::MPFR::Rmpfr_cmp_si($x, -1) < 0) {
                my $r = _mpfr2mpc($x);
                Math::MPC::Rmpc_atanh($r, $r, $ROUND);
                return $r;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_atanh($r, $x, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_atanh($r, $x, $ROUND);
            return $r;
        }
    }

    sub atanh {
        my ($x) = @_;
        bless \__atanh__(_any2mpfr_mpc($$x));
    }

    sub __atan2__ {
        my ($x, $y) = @_;
        goto(join('__', ref($x), ref($y)) =~ tr/:/_/rs);

      Math_MPFR__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_atan2($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_MPC: {
            $x = _mpfr2mpc($x);
            goto Math_MPC__Math_MPC;
        }

        # atan2(x, y) = atan(x/y)
      Math_MPC__Math_MPFR: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_div_fr($r, $x, $y, $ROUND);
            Math::MPC::Rmpc_atan($r, $r, $ROUND);
            return $r;
        }

        # atan2(x, y) = atan(x/y)
      Math_MPC__Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_div($r, $x, $y, $ROUND);
            Math::MPC::Rmpc_atan($r, $r, $ROUND);
            return $r;
        }
    }

    sub atan2 {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__atan2__(_any2mpfr_mpc($$x), _any2mpfr_mpc($$y));
    }

    #
    ## sec / sech / asec / asech
    #

    sub __sec__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_sec($r, $x, $ROUND);
            return $r;
        }

        # sec(x) = 1/cos(x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_cos($r, $x, $ROUND);
            Math::MPC::Rmpc_ui_div($r, 1, $r, $ROUND);
            return $r;
        }
    }

    sub sec {
        my ($x) = @_;
        bless \__sec__(_any2mpfr_mpc($$x));
    }

    sub __sech__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_sech($r, $x, $ROUND);
            return $r;
        }

        # sech(x) = 1/cosh(x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_cosh($r, $x, $ROUND);
            Math::MPC::Rmpc_ui_div($r, 1, $r, $ROUND);
            return $r;
        }
    }

    sub sech {
        my ($x) = @_;
        bless \__sech__(_any2mpfr_mpc($$x));
    }

    sub __asec__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

        # asec(x) = acos(1/x)
      Math_MPFR: {

            # Return a complex number for x > -1 and x < 1
            if (    Math::MPFR::Rmpfr_cmp_ui($x, 1) < 0
                and Math::MPFR::Rmpfr_cmp_si($x, -1) > 0) {
                $x = _mpfr2mpc($x);
                goto Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_ui_div($r, 1, $x, $ROUND);
            Math::MPFR::Rmpfr_acos($r, $r, $ROUND);
            return $r;
        }

        # asec(x) = acos(1/x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_ui_div($r, 1, $x, $ROUND);
            Math::MPC::Rmpc_acos($r, $r, $ROUND);
            return $r;
        }
    }

    sub asec {
        my ($x) = @_;
        bless \__asec__(_any2mpfr_mpc($$x));
    }

    sub __asech__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

        # asech(x) = acosh(1/x)
      Math_MPFR: {

            # Return a complex number for x < 0 or x > 1
            if (   Math::MPFR::Rmpfr_cmp_ui($x, 1) > 0
                or Math::MPFR::Rmpfr_cmp_ui($x, 0) < 0) {
                $x = _mpfr2mpc($x);
                goto Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_ui_div($r, 1, $x, $ROUND);
            Math::MPFR::Rmpfr_acosh($r, $r, $ROUND);
            return $r;
        }

        # asech(x) = acosh(1/x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_ui_div($r, 1, $x, $ROUND);
            Math::MPC::Rmpc_acosh($r, $r, $ROUND);
            return $r;
        }
    }

    sub asech {
        my ($x) = @_;
        bless \__asech__(_any2mpfr_mpc($$x));
    }

    #
    ## csc / csch / acsc / acsch
    #

    sub __csc__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_csc($r, $x, $ROUND);
            return $r;
        }

        # csc(x) = 1/sin(x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_sin($r, $x, $ROUND);
            Math::MPC::Rmpc_ui_div($r, 1, $r, $ROUND);
            return $r;
        }
    }

    sub csc {
        my ($x) = @_;
        bless \__csc__(_any2mpfr_mpc($$x));
    }

    sub __csch__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_csch($r, $x, $ROUND);
            return $r;
        }

        # csch(x) = 1/sinh(x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_sinh($r, $x, $ROUND);
            Math::MPC::Rmpc_ui_div($r, 1, $r, $ROUND);
            return $r;
        }
    }

    sub csch {
        my ($x) = @_;
        bless \__csch__(_any2mpfr_mpc($$x));
    }

    sub __acsc__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

        # acsc(x) = asin(1/x)
      Math_MPFR: {

            # Return a complex number for x > -1 and x < 1
            if (    Math::MPFR::Rmpfr_cmp_ui($x, 1) < 0
                and Math::MPFR::Rmpfr_cmp_si($x, -1) > 0) {
                $x = _mpfr2mpc($x);
                goto Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_ui_div($r, 1, $x, $ROUND);
            Math::MPFR::Rmpfr_asin($r, $r, $ROUND);
            return $r;
        }

        # acsc(x) = asin(1/x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_ui_div($r, 1, $x, $ROUND);
            Math::MPC::Rmpc_asin($r, $r, $ROUND);
            return $r;
        }
    }

    sub acsc {
        my ($x) = @_;
        bless \__acsc__(_any2mpfr_mpc($$x));
    }

    sub __acsch__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

        # acsch(x) = asinh(1/x)
      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_ui_div($r, 1, $x, $ROUND);
            Math::MPFR::Rmpfr_asinh($r, $r, $ROUND);
            return $r;
        }

        # acsch(x) = asinh(1/x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_ui_div($r, 1, $x, $ROUND);
            Math::MPC::Rmpc_asinh($r, $r, $ROUND);
            return $r;
        }
    }

    sub acsch {
        my ($x) = @_;
        bless \__acsch__(_any2mpfr_mpc($$x));
    }

    #
    ## cot / coth / acot / acoth
    #

    sub __cot__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_cot($r, $x, $ROUND);
            return $r;
        }

        # cot(x) = 1/tan(x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_tan($r, $x, $ROUND);
            Math::MPC::Rmpc_ui_div($r, 1, $r, $ROUND);
            return $r;
        }
    }

    sub cot {
        my ($x) = @_;
        bless \__cot__(_any2mpfr_mpc($$x));
    }

    sub __coth__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_coth($r, $x, $ROUND);
            return $r;
        }

        # coth(x) = 1/tanh(x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_tanh($r, $x, $ROUND);
            Math::MPC::Rmpc_ui_div($r, 1, $r, $ROUND);
            return $r;
        }
    }

    sub coth {
        my ($x) = @_;
        bless \__coth__(_any2mpfr_mpc($$x));
    }

    sub __acot__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

        # acot(x) = atan(1/x)
      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_ui_div($r, 1, $x, $ROUND);
            Math::MPFR::Rmpfr_atan($r, $r, $ROUND);
            return $r;
        }

        # acot(x) = atan(1/x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_ui_div($r, 1, $x, $ROUND);
            Math::MPC::Rmpc_atan($r, $r, $ROUND);
            return $r;
        }
    }

    sub acot {
        my ($x) = @_;
        bless \__acot__(_any2mpfr_mpc($$x));
    }

    sub __acoth__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

        # acoth(x) = atanh(1/x)
      Math_MPFR: {

            # Return a complex number for x > -1 and x < 1
            if (    Math::MPFR::Rmpfr_cmp_ui($x, 1) < 0
                and Math::MPFR::Rmpfr_cmp_si($x, -1) > 0) {
                $x = _mpfr2mpc($x);
                goto Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_ui_div($r, 1, $x, $ROUND);
            Math::MPFR::Rmpfr_atanh($r, $r, $ROUND);
            return $r;
        }

        # acoth(x) = atanh(1/x)
      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_ui_div($r, 1, $x, $ROUND);
            Math::MPC::Rmpc_atanh($r, $r, $ROUND);
            return $r;
        }
    }

    sub acoth {
        my ($x) = @_;
        bless \__acoth__(_any2mpfr_mpc($$x));
    }

    sub __cis__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_ui_fr($r, 0, $x, $ROUND);
            Math::MPC::Rmpc_exp($r, $r, $ROUND);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_mul_i($r, $x, 1, $ROUND);
            Math::MPC::Rmpc_exp($r, $r, $ROUND);
            return $r;
        }
    }

    sub cis {
        my ($x) = @_;
        bless \__cis__(_any2mpfr_mpc($$x));
    }

    sub __sin_cos__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $cos = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            my $sin = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            Math::MPFR::Rmpfr_sin_cos($sin, $cos, $x, $ROUND);

            return ($sin, $cos);
        }

      Math_MPC: {
            my $cos = Math::MPC::Rmpc_init2(CORE::int($PREC));
            my $sin = Math::MPC::Rmpc_init2(CORE::int($PREC));

            Math::MPC::Rmpc_sin_cos($sin, $cos, $x, $ROUND, $ROUND);

            return ($sin, $cos);
        }
    }

    sub sin_cos {
        my ($x) = @_;
        my ($sin, $cos) = __sin_cos__(_any2mpfr_mpc($$x));
        ((bless \$sin), (bless \$cos));
    }

    #
    ## Special functions
    #

    sub __agm__ {
        my ($x, $y) = @_;
        goto(join('__', ref($x), ref($y)) =~ tr/:/_/rs);

      Math_MPFR__Math_MPFR: {
            if (   Math::MPFR::Rmpfr_sgn($x) < 0
                or Math::MPFR::Rmpfr_sgn($y) < 0) {
                ($x, $y) = (_mpfr2mpc($x), _mpfr2mpc($y));
                goto Math_MPC__Math_MPC;
            }

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_agm($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_MPC: {

            # agm(0,  x) = 0
            Math::MPC::Rmpc_cmp_si_si($x, 0, 0) || return $x;

            # agm(x, 0) = 0
            Math::MPC::Rmpc_cmp_si_si($y, 0, 0) || return $y;

            $PREC = CORE::int($PREC) if ref($PREC);

            my $a0 = Math::MPC::Rmpc_init2($PREC);
            my $g0 = Math::MPC::Rmpc_init2($PREC);

            my $a1 = Math::MPC::Rmpc_init2($PREC);
            my $g1 = Math::MPC::Rmpc_init2($PREC);

            my $t = Math::MPC::Rmpc_init2($PREC);

            Math::MPC::Rmpc_set($a0, $x, $ROUND);
            Math::MPC::Rmpc_set($g0, $y, $ROUND);

            my $count = 0;
            {
                Math::MPC::Rmpc_add($a1, $a0, $g0, $ROUND);
                Math::MPC::Rmpc_div_2ui($a1, $a1, 1, $ROUND);

                Math::MPC::Rmpc_mul($g1, $a0, $g0, $ROUND);
                Math::MPC::Rmpc_add($t, $a0, $g0, $ROUND);
                Math::MPC::Rmpc_sqr($t, $t, $ROUND);
                Math::MPC::Rmpc_cmp_si_si($t, 0, 0) || return $t;
                Math::MPC::Rmpc_div($g1, $g1, $t, $ROUND);
                Math::MPC::Rmpc_sqrt($g1, $g1, $ROUND);
                Math::MPC::Rmpc_add($t, $a0, $g0, $ROUND);
                Math::MPC::Rmpc_mul($g1, $g1, $t, $ROUND);

                if (Math::MPC::Rmpc_cmp($a0, $a1) and ++$count < $PREC) {
                    Math::MPC::Rmpc_set($a0, $a1, $ROUND);
                    Math::MPC::Rmpc_set($g0, $g1, $ROUND);
                    redo;
                }
            }

            return $g0;
        }

      Math_MPFR__Math_MPC: {
            $x = _mpfr2mpc($x);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Math_MPFR: {
            $y = _mpfr2mpc($y);
            goto Math_MPC__Math_MPC;
        }
    }

    sub agm {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__agm__(_any2mpfr_mpc($$x), _any2mpfr_mpc($$y));
    }

    sub __hypot__ {
        my ($x, $y) = @_;

        # hypot(x, y) = sqrt(x^2 + y^2)

        goto(join('__', ref($x), ref($y)) =~ tr/:/_/rs);

      Math_MPFR__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_hypot($r, $x, $y, $ROUND);
            return $r;
        }

      Math_MPFR__Math_MPC: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::Rmpc_abs($r, $y, $ROUND);
            Math::MPFR::Rmpfr_hypot($r, $r, $x, $ROUND);
            return $r;
        }

      Math_MPC__Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::Rmpc_abs($r, $x, $ROUND);
            Math::MPFR::Rmpfr_hypot($r, $r, $y, $ROUND);
            return $r;
        }

      Math_MPC__Math_MPC: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::Rmpc_abs($r, $x, $ROUND);
            my $t = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::Rmpc_abs($t, $y, $ROUND);
            Math::MPFR::Rmpfr_hypot($r, $r, $t, $ROUND);
            return $r;
        }
    }

    sub hypot {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__hypot__(_any2mpfr_mpc($$x), _any2mpfr_mpc($$y));
    }

    sub gamma {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_gamma($r, _any2mpfr($$x), $ROUND);
        bless \$r;
    }

    sub lngamma {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_lngamma($r, _any2mpfr($$x), $ROUND);
        bless \$r;
    }

    sub lgamma {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_lgamma($r, _any2mpfr($$x), $ROUND);
        bless \$r;
    }

    sub digamma {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_digamma($r, _any2mpfr($$x), $ROUND);
        bless \$r;
    }

    #
    ## beta(x, y) = gamma(x)*gamma(y) / gamma(x+y)
    #
    sub beta {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpfr($$x);
        $y = _any2mpfr($$y);

        my $t1 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));    # gamma(x+y)
        my $t2 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));    # gamma(y)

        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

        Math::MPFR::Rmpfr_add($t1, $x, $y, $ROUND);
        Math::MPFR::Rmpfr_gamma($t1, $t1, $ROUND);
        Math::MPFR::Rmpfr_gamma($r,  $x,  $ROUND);
        Math::MPFR::Rmpfr_gamma($t2, $y,  $ROUND);
        Math::MPFR::Rmpfr_mul($r, $r, $t2, $ROUND);
        Math::MPFR::Rmpfr_div($r, $r, $t1, $ROUND);

        bless \$r;
    }

    #
    ## eta(s) = (1 - 2^(1-s)) * zeta(s)
    #
    sub eta {
        my ($x) = @_;

        $x = _any2mpfr($$x);

        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

        # Special case for eta(1) = log(2)
        if (    Math::MPFR::Rmpfr_integer_p($x)
            and Math::MPFR::Rmpfr_cmp_ui($x, 1) == 0) {
            Math::MPFR::Rmpfr_const_log2($r, $ROUND);
            return bless \$r;
        }

        my $t = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

        Math::MPFR::Rmpfr_ui_sub($r, 1, $x, $ROUND);
        Math::MPFR::Rmpfr_ui_pow($r, 2, $r, $ROUND);
        Math::MPFR::Rmpfr_ui_sub($r, 1, $r, $ROUND);

        Math::MPFR::Rmpfr_zeta($t, $x, $ROUND);
        Math::MPFR::Rmpfr_mul($r, $r, $t, $ROUND);

        bless \$r;
    }

    sub zeta {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

        my $f = _any2mpfr($$x);
        if (    Math::MPFR::Rmpfr_integer_p($f)
            and Math::MPFR::Rmpfr_sgn($f) >= 0
            and Math::MPFR::Rmpfr_fits_ulong_p($f, $ROUND)) {
            Math::MPFR::Rmpfr_zeta_ui($r, Math::MPFR::Rmpfr_get_ui($f, $ROUND), $ROUND);
        }
        else {
            Math::MPFR::Rmpfr_zeta($r, $f, $ROUND);
        }
        bless \$r;
    }

    sub bernfrac {
        my ($n) = @_;

        $n = _any2ui($$n) // goto &nan;

        $n == 0 and return ONE;
        $n > 1 and $n % 2 and return ZERO;    # Bn=0 for odd n>1

        # Using bernfrac() from `Math::Prime::Util::GMP`
        my ($num, $den) = Math::Prime::Util::GMP::bernfrac($n);

        my $q = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_str($q, "$num/$den", 10);
        bless \$q;
    }

    *bern      = \&bernfrac;
    *bernoulli = \&bernfrac;

    sub bernreal {
        my ($n) = @_;

        $n = _any2ui($$n) // goto &nan;

        # |B(n)| = zeta(n) * n! / 2^(n-1) / pi^n

        $n == 0 and return ONE;
        $n == 1 and return do { state $x = bless(\_str2obj('1/2')) };
        $n % 2  and return ZERO;                                        # Bn = 0 for odd n>1

        #local $PREC = CORE::int($n*CORE::log($n)+1);

        my $f = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        my $p = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

        Math::MPFR::Rmpfr_zeta_ui($f, $n, $ROUND);                      # f = zeta(n)
        Math::MPFR::Rmpfr_set_ui($p, $n + 1, $ROUND);                   # p = n+1
        Math::MPFR::Rmpfr_gamma($p, $p, $ROUND);                        # p = gamma(p)

        Math::MPFR::Rmpfr_mul($f, $f, $p, $ROUND);                      # f = f * p

        Math::MPFR::Rmpfr_const_pi($p, $ROUND);                         # p = PI
        Math::MPFR::Rmpfr_pow_ui($p, $p, $n, $ROUND);                   # p = p^n

        Math::MPFR::Rmpfr_div_2exp($f, $f, $n - 1, $ROUND);             # f = f / 2^(n-1)

        Math::MPFR::Rmpfr_div($f, $f, $p, $ROUND);                      # f = f/p
        Math::MPFR::Rmpfr_neg($f, $f, $ROUND) if $n % 4 == 0;

        bless \$f;
    }

    sub harmfrac {
        my ($n) = @_;

        $n = _any2ui($$n) // goto &nan;
        $n || return ZERO();

        # Using harmfrac() from Math::Prime::Util::GMP
        my ($num, $den) = Math::Prime::Util::GMP::harmfrac($n);

        my $q = Math::GMPq::Rmpq_init();
        Math::GMPq::Rmpq_set_str($q, "$num/$den", 10);
        bless \$q;
    }

    *harm     = \&harmfrac;
    *harmonic = \&harmfrac;

    sub harmreal {
        my ($x) = @_;

        $x = _any2mpfr($$x);

        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_add_ui($r, $x, 1, $ROUND);
        Math::MPFR::Rmpfr_digamma($r, $r, $ROUND);

        my $t = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_const_euler($t, $ROUND);
        Math::MPFR::Rmpfr_add($r, $r, $t, $ROUND);

        bless \$r;
    }

    sub erf {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_erf($r, _any2mpfr($$x), $ROUND);
        bless \$r;
    }

    sub erfc {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_erfc($r, _any2mpfr($$x), $ROUND);
        bless \$r;
    }

    sub bessel_j {
        my ($x, $n) = @_;

        $n = defined($n) ? do { _valid(\$n); __numify__($$n) } : 0;

        if ($n < LONG_MIN or $n > ULONG_MAX) {
            return ZERO;
        }

        $x = _any2mpfr($$x);
        $n = CORE::int($n);

        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

        if ($n == 0) {
            Math::MPFR::Rmpfr_j0($r, $x, $ROUND);
        }
        elsif ($n == 1) {
            Math::MPFR::Rmpfr_j1($r, $x, $ROUND);
        }
        else {
            Math::MPFR::Rmpfr_jn($r, $n, $x, $ROUND);
        }

        bless \$r;
    }

    *BesselJ = \&bessel_j;

    sub bessel_y {
        my ($x, $n) = @_;

        $n = defined($n) ? do { _valid(\$n); __numify__($$n) } : 0;

        if ($n < LONG_MIN or $n > ULONG_MAX) {
            if (__cmp__($$x, 0) < 0) {
                return nan();
            }
            return ($n < 0 ? inf() : ninf());
        }

        $x = _any2mpfr($$x);
        $n = CORE::int($n);

        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

        if ($n == 0) {
            Math::MPFR::Rmpfr_y0($r, $x, $ROUND);
        }
        elsif ($n == 1) {
            Math::MPFR::Rmpfr_y1($r, $x, $ROUND);
        }
        else {
            Math::MPFR::Rmpfr_yn($r, $n, $x, $ROUND);
        }

        bless \$r;
    }

    *BesselY = \&bessel_y;

    sub eint {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_eint($r, _any2mpfr($$x), $ROUND);
        bless \$r;
    }

    *ei = \&eint;
    *Ei = \&eint;

    sub ai {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_ai($r, _any2mpfr($$x), $ROUND);
        bless \$r;
    }

    *airy = \&ai;
    *Ai   = \&ai;

    sub li {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_log($r, _any2mpfr($$x), $ROUND);
        Math::MPFR::Rmpfr_eint($r, $r, $ROUND);
        bless \$r;
    }

    *Li = \&li;

    sub li2 {
        my ($x) = @_;
        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_li2($r, _any2mpfr($$x), $ROUND);
        bless \$r;
    }

    *Li2 = \&li2;

    #
    ## Comparison and testing operations
    #

    sub __eq__ {
        my ($x, $y) = @_;

        goto(join('__', ref($x), ref($y) || 'Scalar') =~ tr/:/_/rs);

        #
        ## MPFR
        #
      Math_MPFR__Math_MPFR: {
            return Math::MPFR::Rmpfr_equal_p($x, $y);
        }

      Math_MPFR__Math_GMPz: {
            return (Math::MPFR::Rmpfr_integer_p($x) and Math::MPFR::Rmpfr_cmp_z($x, $y) == 0);
        }

      Math_MPFR__Math_GMPq: {
            return (Math::MPFR::Rmpfr_number_p($x) and Math::MPFR::Rmpfr_cmp_q($x, $y) == 0);
        }

      Math_MPFR__Math_MPC: {
            $x = _mpfr2mpc($x);
            goto Math_MPC__Math_MPC;
        }

      Math_MPFR__Scalar: {
            return (
                    Math::MPFR::Rmpfr_integer_p($x)
                      and (
                           $y < 0
                           ? Math::MPFR::Rmpfr_cmp_si($x, $y)
                           : Math::MPFR::Rmpfr_cmp_ui($x, $y)
                      ) == 0
                   );
        }

        #
        ## GMPq
        #
      Math_GMPq__Math_GMPq: {
            return Math::GMPq::Rmpq_equal($x, $y);
        }

      Math_GMPq__Math_GMPz: {
            return (Math::GMPq::Rmpq_integer_p($x) and Math::GMPq::Rmpq_cmp_z($x, $y) == 0);
        }

      Math_GMPq__Math_MPFR: {
            return (Math::MPFR::Rmpfr_number_p($y) and Math::MPFR::Rmpfr_cmp_q($y, $x) == 0);
        }

      Math_GMPq__Math_MPC: {
            $x = _mpq2mpc($x);
            goto Math_MPC__Math_MPC;
        }

      Math_GMPq__Scalar: {
            return (
                    Math::GMPq::Rmpq_integer_p($x)
                      and (
                           $y < 0
                           ? Math::GMPq::Rmpq_cmp_si($x, $y, 1)
                           : Math::GMPq::Rmpq_cmp_ui($x, $y, 1)
                      ) == 0
                   );
        }

        #
        ## GMPz
        #
      Math_GMPz__Math_GMPz: {
            return (Math::GMPz::Rmpz_cmp($x, $y) == 0);
        }

      Math_GMPz__Math_GMPq: {
            return (Math::GMPq::Rmpq_integer_p($y) and Math::GMPq::Rmpq_cmp_z($y, $x) == 0);
        }

      Math_GMPz__Math_MPFR: {
            return (Math::MPFR::Rmpfr_integer_p($y) and Math::MPFR::Rmpfr_cmp_z($y, $x) == 0);
        }

      Math_GMPz__Math_MPC: {
            $x = _mpz2mpc($x);
            goto Math_MPC__Math_MPC;
        }

      Math_GMPz__Scalar: {
            return (
                    (
                     $y < 0
                     ? Math::GMPz::Rmpz_cmp_si($x, $y)
                     : Math::GMPz::Rmpz_cmp_ui($x, $y)
                    ) == 0
                   );
        }

        #
        ## MPC
        #
      Math_MPC__Math_MPC: {
            my $f1 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            my $f2 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            Math::MPC::RMPC_RE($f1, $x);
            Math::MPC::RMPC_RE($f2, $y);

            Math::MPFR::Rmpfr_equal_p($f1, $f2) || return 0;

            Math::MPC::RMPC_IM($f1, $x);
            Math::MPC::RMPC_IM($f2, $y);

            return Math::MPFR::Rmpfr_equal_p($f1, $f2);
        }

      Math_MPC__Math_GMPz: {
            $y = _mpz2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Math_GMPq: {
            $y = _mpq2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Math_MPFR: {
            $y = _mpfr2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Scalar: {
            my $f = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::RMPC_IM($f, $x);
            Math::MPFR::Rmpfr_zero_p($f) || return 0;
            Math::MPC::RMPC_RE($f, $x);
            $x = $f;
            goto Math_MPFR__Scalar;
        }
    }

    sub eq {
        my ($x, $y) = @_;

        ref($y) ne __PACKAGE__
          and return Sidef::Types::Bool::Bool::FALSE;

        __eq__($$x, $$y)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub __ne__ {
        my ($x, $y) = @_;

        goto(join('__', ref($x), ref($y) || 'Scalar') =~ tr/:/_/rs);

        #
        ## MPFR
        #
      Math_MPFR__Math_MPFR: {
            return !Math::MPFR::Rmpfr_equal_p($x, $y);
        }

      Math_MPFR__Math_GMPz: {
            return (!Math::MPFR::Rmpfr_integer_p($x) or Math::MPFR::Rmpfr_cmp_z($x, $y) != 0);
        }

      Math_MPFR__Math_GMPq: {
            return (!Math::MPFR::Rmpfr_number_p($x) or Math::MPFR::Rmpfr_cmp_q($x, $y) != 0);
        }

      Math_MPFR__Math_MPC: {
            $x = _mpfr2mpc($x);
            goto Math_MPC__Math_MPC;
        }

      Math_MPFR__Scalar: {
            return (
                    !Math::MPFR::Rmpfr_integer_p($x)
                      or (
                          $y < 0
                          ? Math::MPFR::Rmpfr_cmp_si($x, $y)
                          : Math::MPFR::Rmpfr_cmp_ui($x, $y)
                      ) != 0
                   );
        }

        #
        ## GMPq
        #
      Math_GMPq__Math_GMPq: {
            return !Math::GMPq::Rmpq_equal($x, $y);
        }

      Math_GMPq__Math_GMPz: {
            return (!Math::GMPq::Rmpq_integer_p($x) or Math::GMPq::Rmpq_cmp_z($x, $y) != 0);
        }

      Math_GMPq__Math_MPFR: {
            return (!Math::MPFR::Rmpfr_number_p($y) or Math::MPFR::Rmpfr_cmp_q($y, $x) != 0);
        }

      Math_GMPq__Math_MPC: {
            $x = _mpq2mpc($x);
            goto Math_MPC__Math_MPC;
        }

      Math_GMPq__Scalar: {
            return (
                    !Math::GMPq::Rmpq_integer_p($x)
                      or (
                          $y < 0
                          ? Math::GMPq::Rmpq_cmp_si($x, $y, 1)
                          : Math::GMPq::Rmpq_cmp_ui($x, $y, 1)
                      ) != 0
                   );
        }

        #
        ## GMPz
        #
      Math_GMPz__Math_GMPz: {
            return (Math::GMPz::Rmpz_cmp($x, $y) != 0);
        }

      Math_GMPz__Math_GMPq: {
            return (!Math::GMPq::Rmpq_integer_p($y) or Math::GMPq::Rmpq_cmp_z($y, $x) != 0);
        }

      Math_GMPz__Math_MPFR: {
            return (!Math::MPFR::Rmpfr_integer_p($y) or Math::MPFR::Rmpfr_cmp_z($y, $x) != 0);
        }

      Math_GMPz__Math_MPC: {
            $x = _mpz2mpc($x);
            goto Math_MPC__Math_MPC;
        }

      Math_GMPz__Scalar: {
            return (
                    (
                     $y < 0
                     ? Math::GMPz::Rmpz_cmp_si($x, $y)
                     : Math::GMPz::Rmpz_cmp_ui($x, $y)
                    ) != 0
                   );
        }

        #
        ## MPC
        #
      Math_MPC__Math_MPC: {

            my $f1 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            my $f2 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            Math::MPC::RMPC_RE($f1, $x);
            Math::MPC::RMPC_RE($f2, $y);

            Math::MPFR::Rmpfr_equal_p($f1, $f2) || return 1;

            Math::MPC::RMPC_IM($f1, $x);
            Math::MPC::RMPC_IM($f2, $y);

            return !Math::MPFR::Rmpfr_equal_p($f1, $f2);
        }

      Math_MPC__Math_GMPz: {
            $y = _mpz2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Math_GMPq: {
            $y = _mpq2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Math_MPFR: {
            $y = _mpfr2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Scalar: {
            my $f = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::RMPC_IM($f, $x);
            Math::MPFR::Rmpfr_zero_p($f) || return 1;
            Math::MPC::RMPC_RE($f, $x);
            $x = $f;
            goto Math_MPFR__Scalar;
        }
    }

    sub ne {
        my ($x, $y) = @_;

        ref($y) ne __PACKAGE__
          and return Sidef::Types::Bool::Bool::TRUE;

        __ne__($$x, $$y)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub __cmp__ {
        my ($x, $y) = @_;

        goto(join('__', ref($x), ref($y) || 'Scalar') =~ tr/:/_/rs);

        #
        ## MPFR
        #
      Math_MPFR__Math_MPFR: {
            if (   Math::MPFR::Rmpfr_nan_p($x)
                or Math::MPFR::Rmpfr_nan_p($y)) {
                return undef;
            }

            return Math::MPFR::Rmpfr_cmp($x, $y);
        }

      Math_MPFR__Math_GMPz: {
            Math::MPFR::Rmpfr_nan_p($x) && return undef;
            return Math::MPFR::Rmpfr_cmp_z($x, $y);
        }

      Math_MPFR__Math_GMPq: {
            Math::MPFR::Rmpfr_nan_p($x) && return undef;
            return Math::MPFR::Rmpfr_cmp_q($x, $y);
        }

      Math_MPFR__Math_MPC: {
            $x = _mpfr2mpc($x);
            goto Math_MPC__Math_MPC;
        }

      Math_MPFR__Scalar: {
            Math::MPFR::Rmpfr_nan_p($x) && return undef;
            return (
                    $y < 0
                    ? Math::MPFR::Rmpfr_cmp_si($x, $y)
                    : Math::MPFR::Rmpfr_cmp_ui($x, $y)
                   );
        }

        #
        ## GMPq
        #
      Math_GMPq__Math_GMPq: {
            return Math::GMPq::Rmpq_cmp($x, $y);
        }

      Math_GMPq__Math_GMPz: {
            return Math::GMPq::Rmpq_cmp_z($x, $y);
        }

      Math_GMPq__Math_MPFR: {
            Math::MPFR::Rmpfr_nan_p($y) && return undef;
            return -(Math::MPFR::Rmpfr_cmp_q($y, $x));
        }

      Math_GMPq__Math_MPC: {
            $x = _mpq2mpc($x);
            goto Math_MPC__Math_MPC;
        }

      Math_GMPq__Scalar: {
            return (
                    $y < 0
                    ? Math::GMPq::Rmpq_cmp_si($x, $y, 1)
                    : Math::GMPq::Rmpq_cmp_ui($x, $y, 1)
                   );
        }

        #
        ## GMPz
        #
      Math_GMPz__Math_GMPz: {
            return Math::GMPz::Rmpz_cmp($x, $y);
        }

      Math_GMPz__Math_GMPq: {
            return -(Math::GMPq::Rmpq_cmp_z($y, $x));
        }

      Math_GMPz__Math_MPFR: {
            Math::MPFR::Rmpfr_nan_p($y) && return undef;
            return -(Math::MPFR::Rmpfr_cmp_z($y, $x));
        }

      Math_GMPz__Math_MPC: {
            $x = _mpz2mpc($x);
            goto Math_MPC__Math_MPC;
        }

      Math_GMPz__Scalar: {
            return (
                    $y < 0
                    ? Math::GMPz::Rmpz_cmp_si($x, $y)
                    : Math::GMPz::Rmpz_cmp_ui($x, $y)
                   );
        }

        #
        ## MPC
        #
      Math_MPC__Math_MPC: {
            my $f = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            Math::MPC::RMPC_RE($f, $x);
            Math::MPFR::Rmpfr_nan_p($f) && return undef;

            Math::MPC::RMPC_RE($f, $y);
            Math::MPFR::Rmpfr_nan_p($f) && return undef;

            Math::MPC::RMPC_IM($f, $x);
            Math::MPFR::Rmpfr_nan_p($f) && return undef;

            Math::MPC::RMPC_IM($f, $y);
            Math::MPFR::Rmpfr_nan_p($f) && return undef;

            my $si = Math::MPC::Rmpc_cmp($x, $y);
            my $re_cmp = Math::MPC::RMPC_INEX_RE($si);
            $re_cmp == 0 or return $re_cmp;
            return Math::MPC::RMPC_INEX_IM($si);
        }

      Math_MPC__Math_GMPz: {
            $y = _mpz2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Math_GMPq: {
            $y = _mpq2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Math_MPFR: {
            $y = _mpfr2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Scalar: {
            $y = _any2mpc(_str2obj($y));
            goto Math_MPC__Math_MPC;
        }
    }

    sub cmp {
        my ($x, $y) = @_;
        _valid(\$y);
        my $cmp = __cmp__($$x, $$y) // return undef;
        !$cmp ? ZERO : ($cmp > 0) ? ONE : MONE;
    }

    # TODO: add the acmp() method.

    sub gt {
        my ($x, $y) = @_;
        _valid(\$y);
        ((__cmp__($$x, $$y) // return undef) > 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub ge {
        my ($x, $y) = @_;
        _valid(\$y);
        ((__cmp__($$x, $$y) // return undef) >= 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub lt {
        my ($x, $y) = @_;
        _valid(\$y);
        ((__cmp__($$x, $$y) // return undef) < 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub le {
        my ($x, $y) = @_;
        _valid(\$y);
        ((__cmp__($$x, $$y) // return undef) <= 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_zero {
        my ($x) = @_;
        __eq__($$x, 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_one {
        my ($x) = @_;
        __eq__($$x, 1)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_mone {
        my ($x) = @_;
        __eq__($$x, -1)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_positive {
        my ($x) = @_;
        ((__cmp__($$x, 0) // return undef) > 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    *is_pos = \&is_positive;

    sub is_negative {
        my ($x) = @_;
        ((__cmp__($$x, 0) // return undef) < 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    *is_neg = \&is_negative;

    sub __sgn__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            goto &Math::MPFR::Rmpfr_sgn;
        }

      Math_GMPq: {
            goto &Math::GMPq::Rmpq_sgn;
        }

      Math_GMPz: {
            goto &Math::GMPz::Rmpz_sgn;
        }

      Math_MPC: {
            my $abs = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::Rmpc_abs($abs, $x, $ROUND);

            if (Math::MPFR::Rmpfr_zero_p($abs)) {    # it's zero
                return 0;
            }

            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_div_fr($r, $x, $abs, $ROUND);
            return $r;
        }
    }

    sub sign {
        my ($x) = @_;
        my $r = __sgn__($$x);
        if (ref($r)) {
            bless \$r;
        }
        else {
            ($r < 0) ? MONE : ($r > 0) ? ONE : ZERO;
        }
    }

    *sgn = \&sign;

    sub popcount {
        my ($x) = @_;
        my $z = _any2mpz($$x) // return MONE;

        if (Math::GMPz::Rmpz_sgn($z) < 0) {
            my $t = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_neg($t, $z);
            $z = $t;
        }

        __PACKAGE__->_set_uint(Math::GMPz::Rmpz_popcount($z));
    }

    sub __is_int__ {
        my ($x) = @_;

        ref($x) eq 'Math::GMPz' && return 1;
        ref($x) eq 'Math::GMPq' && return Math::GMPq::Rmpq_integer_p($x);
        ref($x) eq 'Math::MPFR' && return Math::MPFR::Rmpfr_integer_p($x);

        (@_) = _any2mpfr($x);
        goto __SUB__;
    }

    sub is_int {
        my ($x) = @_;
        __is_int__($$x)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub __is_rat__ {
        my ($x) = @_;
        (ref($x) eq 'Math::GMPz' or ref($x) eq 'Math::GMPq');
    }

    sub is_rat {
        my ($x) = @_;
        __is_rat__($$x)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub __is_real__ {
        my ($x) = @_;

        ref($x) eq 'Math::GMPz' && return 1;
        ref($x) eq 'Math::GMPq' && return 1;
        ref($x) eq 'Math::MPFR' && return Math::MPFR::Rmpfr_number_p($x);

        (@_) = _any2mpfr($x);
        goto __SUB__;
    }

    sub is_real {
        my ($x) = @_;
        __is_real__($$x)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub __is_imag__ {
        my ($x) = @_;

        ref($x) eq 'Math::MPC' or return 0;

        my $f = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPC::RMPC_RE($f, $x);
        Math::MPFR::Rmpfr_zero_p($f) || return 0;    # is complex
        Math::MPC::RMPC_IM($f, $x);
        !Math::MPFR::Rmpfr_zero_p($f);
    }

    sub is_imag {
        my ($x) = @_;
        __is_imag__($$x)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub __is_complex__ {
        my ($x) = @_;

        ref($x) eq 'Math::MPC' or return 0;

        my $f = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPC::RMPC_IM($f, $x);
        Math::MPFR::Rmpfr_zero_p($f) && return 0;    # is real
        Math::MPC::RMPC_RE($f, $x);
        !Math::MPFR::Rmpfr_zero_p($f);
    }

    sub is_complex {
        my ($x) = @_;
        __is_complex__($$x)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_even {
        my ($x) = @_;
        (__is_int__($$x) && Math::GMPz::Rmpz_even_p(_any2mpz($$x) // (return Sidef::Types::Bool::Bool::FALSE)))
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_odd {
        my ($x) = @_;
        (__is_int__($$x) && Math::GMPz::Rmpz_odd_p(_any2mpz($$x) // (return Sidef::Types::Bool::Bool::FALSE)))
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_div {
        my ($x, $y) = @_;
        _valid(\$y);
        __eq__(__mod__($$x, $$y), 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub divides {
        my ($x, $y) = @_;
        _valid(\$y);
        __eq__(__mod__($$y, $$x), 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub __is_inf__ {
        my ($x) = @_;

        ref($x) eq 'Math::GMPz' && return 0;
        ref($x) eq 'Math::GMPq' && return 0;
        ref($x) eq 'Math::MPFR' && return (Math::MPFR::Rmpfr_inf_p($x) and Math::MPFR::Rmpfr_sgn($x) > 0);

        (@_) = _any2mpfr($x);
        goto __SUB__;
    }

    sub is_inf {
        my ($x) = @_;
        __is_inf__($$x)
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub __is_ninf__ {
        my ($x) = @_;

        ref($x) eq 'Math::GMPz' && return 0;
        ref($x) eq 'Math::GMPq' && return 0;
        ref($x) eq 'Math::MPFR' && return (Math::MPFR::Rmpfr_inf_p($x) and Math::MPFR::Rmpfr_sgn($x) < 0);

        (@_) = _any2mpfr($x);
        goto __SUB__;
    }

    sub is_ninf {
        my ($x) = @_;
        __is_ninf__($$x)
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_nan {
        my ($x) = @_;

        $x = $$x;

        ref($x) eq 'Math::GMPz' && return Sidef::Types::Bool::Bool::FALSE;
        ref($x) eq 'Math::GMPq' && return Sidef::Types::Bool::Bool::FALSE;
        ref($x) eq 'Math::MPFR'
          && return (
                     Math::MPFR::Rmpfr_nan_p($x)
                     ? Sidef::Types::Bool::Bool::TRUE
                     : Sidef::Types::Bool::Bool::FALSE
                    );

        my $t = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

        Math::MPC::RMPC_RE($t, $x);
        Math::MPFR::Rmpfr_nan_p($t) && return Sidef::Types::Bool::Bool::TRUE;

        Math::MPC::RMPC_IM($t, $x);
        Math::MPFR::Rmpfr_nan_p($t) && return Sidef::Types::Bool::Bool::TRUE;

        return Sidef::Types::Bool::Bool::FALSE;
    }

    sub max {
        my ($x, $y) = @_;
        _valid(\$y);
        (__cmp__($$x, $$y) // return undef) > 0 ? $x : $y;
    }

    sub min {
        my ($x, $y) = @_;
        _valid(\$y);
        (__cmp__($$x, $$y) // return undef) < 0 ? $x : $y;
    }

    sub as_int {
        my ($x, $y) = @_;

        my $base = 10;
        if (defined($y)) {
            _valid(\$y);
            $base = _any2ui($$y) // 0;
            if ($base < 2 or $base > 36) {
                die "[ERROR] Number.as_int(): base must be between 2 and 36, got $y";
            }
        }

        Sidef::Types::String::String->new(Math::GMPz::Rmpz_get_str((_any2mpz($$x) // return undef), $base));
    }

    sub __base__ {
        my ($x, $base) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_GMPz: {
            return Math::GMPz::Rmpz_get_str($x, $base);
        }

      Math_GMPq: {
            return Math::GMPq::Rmpq_get_str($x, $base);
        }

      Math_MPFR: {
            return Math::MPFR::Rmpfr_get_str($x, $base, CORE::int($PREC) >> 2, $ROUND);
        }

      Math_MPC: {
            my $fr = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPC::RMPC_RE($fr, $x);
            my $real = __base__($fr, $base);
            Math::MPC::RMPC_IM($fr, $x);
            return $real if Math::MPFR::Rmpfr_zero_p($fr);
            my $imag = __base__($fr, $base);
            return "($real $imag)";
        }
    }

    sub base {
        my ($x, $y) = @_;

        my $base = 10;
        if (defined($y)) {
            _valid(\$y);
            $base = _any2ui($$y) // 0;
            if ($base < 2 or $base > 36) {
                die "[ERROR] Number.base(): base must be between 2 and 36, got $y";
            }
        }

        Sidef::Types::String::String->new(($base == 10) ? __stringify__($$x) : __base__($$x, $base));
    }

    *in_base = \&base;

    sub as_rat {
        my ($x, $y) = @_;

        my $base = 10;
        if (defined($y)) {
            _valid(\$y);
            $base = _any2ui($$y) // 0;
            if ($base < 2 or $base > 36) {
                die "[ERROR] base must be between 2 and 36, got $y";
            }
        }

        my $str =
          ref($$x) eq 'Math::GMPz'
          ? Math::GMPz::Rmpz_get_str($$x, $base)
          : Math::GMPq::Rmpq_get_str((_any2mpq($$x) // return undef), $base);

        Sidef::Types::String::String->new($str);
    }

    sub as_frac {
        my ($x, $y) = @_;

        my $base = 10;
        if (defined($y)) {
            _valid(\$y);
            $base = _any2ui($$y) // 0;
            if ($base < 2 or $base > 36) {
                die "as_frac(): base must be between 2 and 36, got $y";
            }
        }

        my $str =
          ref($$x) eq 'Math::GMPz'
          ? Math::GMPz::Rmpz_get_str($$x, $base)
          : Math::GMPq::Rmpq_get_str((_any2mpq($$x) // return undef), $base);

        $str .= '/1' if (index($str, '/') == -1);

        Sidef::Types::String::String->new($str);
    }

    sub as_float {
        my ($x, $prec) = @_;

        if (defined($prec)) {
            _valid(\$prec);
            $prec = (_any2ui($$prec) // 0) << 2;

            state $min_prec = Math::MPFR::RMPFR_PREC_MIN();
            state $max_prec = Math::MPFR::RMPFR_PREC_MAX();

            if ($prec < $min_prec or $prec > $max_prec) {
                die "as_float(): precision must be between $min_prec and $max_prec, got ", $prec >> 2;
            }
        }
        else {
            $prec = CORE::int($PREC);
        }

        local $PREC = $prec;
        Sidef::Types::String::String->new(__stringify__(_any2mpfr_mpc($$x)));
    }

    *as_dec = \&as_float;

    sub dump {
        my ($x) = @_;
        Sidef::Types::String::String->new(__stringify__($$x));
    }

    sub as_bin {
        my ($x) = @_;
        Sidef::Types::String::String->new(Math::GMPz::Rmpz_get_str((_any2mpz($$x) // return undef), 2));
    }

    sub as_oct {
        my ($x) = @_;
        Sidef::Types::String::String->new(Math::GMPz::Rmpz_get_str((_any2mpz($$x) // return undef), 8));
    }

    sub as_hex {
        my ($x) = @_;
        Sidef::Types::String::String->new(Math::GMPz::Rmpz_get_str((_any2mpz($$x) // return undef), 16));
    }

    sub digits {
        my ($x, $y) = @_;

        my $str = as_int($x, $y) // return undef;
        my @digits = split(//, "$str");
        shift(@digits) if $digits[0] eq '-';

        Sidef::Types::Array::Array->new(
            map {
                defined($y)
                  ? Sidef::Types::String::String->new($_)
                  : __PACKAGE__->_set_uint($_)
              } @digits
        );
    }

    sub digit {
        my ($x, $y, $z) = @_;

        _valid(\$y);

        my $str = as_int($x, $z) // return undef;
        my @digits = split(//, "$str");
        shift(@digits) if $digits[0] eq '-';

        $y = _any2si($$y) // return undef;
        exists($digits[$y])
          ? (
             defined($z)
             ? Sidef::Types::String::String->new($digits[$y])
             : __PACKAGE__->_set_uint($digits[$y])
            )
          : undef;
    }

    sub length {
        my ($x) = @_;
        my ($z) = _any2mpz($$x) // return MONE;
        my $neg = (Math::GMPz::Rmpz_sgn($z) < 0) ? 1 : 0;
        __PACKAGE__->_set_uint(CORE::length(Math::GMPz::Rmpz_get_str($z, 10)) - $neg);
    }

    *len  = \&length;
    *size = \&length;

    sub __floor__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_floor($r, $x);
            return $r;
        }

      Math_GMPq: {
            my $r = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($r, $x);
            Math::GMPq::Rmpq_integer_p($x) && return $r;
            Math::GMPz::Rmpz_sub_ui($r, $r, 1) if Math::GMPq::Rmpq_sgn($x) < 0;
            return $r;
        }

      Math_MPC: {
            my $real = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            my $imag = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            Math::MPC::RMPC_RE($real, $x);
            Math::MPC::RMPC_IM($imag, $x);

            Math::MPFR::Rmpfr_floor($real, $real);
            Math::MPFR::Rmpfr_floor($imag, $imag);

            if (Math::MPFR::Rmpfr_zero_p($imag)) {
                return $real;
            }

            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_fr_fr($r, $real, $imag, $ROUND);
            return $r;
        }
    }

    sub floor {
        my ($x) = @_;
        ref($$x) eq 'Math::GMPz' and return $x;    # already an integer
        bless \__floor__($$x);
    }

    sub __ceil__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_ceil($r, $x);
            return $r;
        }

      Math_GMPq: {
            my $r = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($r, $x);
            Math::GMPq::Rmpq_integer_p($x) && return $r;
            Math::GMPz::Rmpz_add_ui($r, $r, 1) if Math::GMPq::Rmpq_sgn($x) > 0;
            return $r;
        }

      Math_MPC: {
            my $real = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            my $imag = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            Math::MPC::RMPC_RE($real, $x);
            Math::MPC::RMPC_IM($imag, $x);

            Math::MPFR::Rmpfr_ceil($real, $real);
            Math::MPFR::Rmpfr_ceil($imag, $imag);

            if (Math::MPFR::Rmpfr_zero_p($imag)) {
                return $real;
            }

            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_fr_fr($r, $real, $imag, $ROUND);
            return $r;
        }
    }

    sub ceil {
        my ($x) = @_;
        ref($$x) eq 'Math::GMPz' and return $x;    # already an integer
        bless \__ceil__($$x);
    }

    sub __inc__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_GMPz: {
            my $r = Math::GMPz::Rmpz_init_set($x);
            Math::GMPz::Rmpz_add_ui($r, $r, 1);
            return $r;
        }

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_add_ui($r, $x, 1, $ROUND);
            return $r;
        }

      Math_GMPq: {
            state $one = Math::GMPz::Rmpz_init_set_ui_nobless(1);
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_add_z($r, $x, $one);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_add_ui($r, $x, 1, $ROUND);
            return $r;
        }
    }

    sub inc {
        my ($x) = @_;
        bless \__inc__($$x);
    }

    sub __dec__ {
        my ($x) = @_;
        goto(ref($x) =~ tr/:/_/rs);

      Math_GMPz: {
            my $r = Math::GMPz::Rmpz_init_set($x);
            Math::GMPz::Rmpz_sub_ui($r, $r, 1);
            return $r;
        }

      Math_MPFR: {
            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_sub_ui($r, $x, 1, $ROUND);
            return $r;
        }

      Math_GMPq: {
            state $mone = Math::GMPz::Rmpz_init_set_si_nobless(-1);
            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_add_z($r, $x, $mone);
            return $r;
        }

      Math_MPC: {
            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_sub_ui($r, $x, 1, $ROUND);
            return $r;
        }
    }

    sub dec {
        my ($x) = @_;
        bless \__dec__($$x);
    }

    sub __mod__ {
        my ($x, $y) = @_;
        goto(join('__', ref($x), ref($y) || 'Scalar') =~ tr/:/_/rs);

        #
        ## GMPq
        #
      Math_GMPq__Math_GMPq: {

            Math::GMPq::Rmpq_sgn($y)
              || goto &_nan;

            my $quo = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set($quo, $x);
            Math::GMPq::Rmpq_div($quo, $quo, $y);

            # Floor
            if (!Math::GMPq::Rmpq_integer_p($quo)) {
                my $z = Math::GMPz::Rmpz_init();
                Math::GMPz::Rmpz_set_q($z, $quo);
                Math::GMPz::Rmpz_sub_ui($z, $z, 1) if Math::GMPq::Rmpq_sgn($quo) < 0;
                Math::GMPq::Rmpq_set_z($quo, $z);
            }

            Math::GMPq::Rmpq_mul($quo, $quo, $y);
            Math::GMPq::Rmpq_sub($quo, $x, $quo);

            return $quo;
        }

      Math_GMPq__Math_GMPz: {
            $y = _mpz2mpq($y);
            goto Math_GMPq__Math_GMPq;
        }

      Math_GMPq__Math_MPFR: {
            $x = _mpq2mpfr($x);
            goto Math_MPFR__Math_MPFR;
        }

      Math_GMPq__Math_MPC: {
            $x = _mpq2mpc($x);
            goto Math_MPC__Math_MPC;
        }

        #
        ## GMPz
        #
      Math_GMPz__Math_GMPz: {

            my $sgn_y = Math::GMPz::Rmpz_sgn($y)
              || goto &_nan;

            my $r = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_mod($r, $x, $y);

            if (!Math::GMPz::Rmpz_sgn($r)) {
                ## ok
            }
            elsif ($sgn_y < 0) {
                Math::GMPz::Rmpz_add($r, $r, $y);
            }

            return $r;
        }

      Math_GMPz__Scalar: {
            my $r = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_mod_ui($r, $x, $y);
            return $r;
        }

      Math_GMPz__Math_GMPq: {
            $x = _mpz2mpq($x);
            goto Math_GMPq__Math_GMPq;
        }

      Math_GMPz__Math_MPFR: {
            $x = _mpz2mpfr($x);
            goto Math_MPFR__Math_MPFR;
        }

      Math_GMPz__Math_MPC: {
            $x = _mpz2mpc($x);
            goto Math_MPC__Math_MPC;
        }

        #
        ## MPFR
        #
      Math_MPFR__Math_MPFR: {
            my $quo = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_div($quo, $x, $y, $ROUND);
            Math::MPFR::Rmpfr_floor($quo, $quo);
            Math::MPFR::Rmpfr_mul($quo, $quo, $y, $ROUND);
            Math::MPFR::Rmpfr_sub($quo, $x, $quo, $ROUND);
            return $quo;
        }

      Math_MPFR__Scalar: {
            my $quo = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_div_ui($quo, $x, $y, $ROUND);
            Math::MPFR::Rmpfr_floor($quo, $quo);
            Math::MPFR::Rmpfr_mul_ui($quo, $quo, $y, $ROUND);
            Math::MPFR::Rmpfr_sub($quo, $x, $quo, $ROUND);
            return $quo;
        }

      Math_MPFR__Math_GMPq: {
            my $quo = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_div_q($quo, $x, $y, $ROUND);
            Math::MPFR::Rmpfr_floor($quo, $quo);
            Math::MPFR::Rmpfr_mul_q($quo, $quo, $y, $ROUND);
            Math::MPFR::Rmpfr_sub($quo, $x, $quo, $ROUND);
            return $quo;
        }

      Math_MPFR__Math_GMPz: {
            my $quo = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_div_z($quo, $x, $y, $ROUND);
            Math::MPFR::Rmpfr_floor($quo, $quo);
            Math::MPFR::Rmpfr_mul_z($quo, $quo, $y, $ROUND);
            Math::MPFR::Rmpfr_sub($quo, $x, $quo, $ROUND);
            return $quo;
        }

      Math_MPFR__Math_MPC: {
            $x = _mpfr2mpc($x);
            goto Math_MPC__Math_MPC;
        }

        #
        ## MPC
        #
      Math_MPC__Math_MPC: {
            my $quo = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_div($quo, $x, $y, $ROUND);

            my $real = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            my $imag = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            Math::MPC::RMPC_RE($real, $quo);
            Math::MPC::RMPC_IM($imag, $quo);

            Math::MPFR::Rmpfr_floor($real, $real);
            Math::MPFR::Rmpfr_floor($imag, $imag);

            Math::MPC::Rmpc_set_fr_fr($quo, $real, $imag, $ROUND);

            Math::MPC::Rmpc_mul($quo, $quo, $y, $ROUND);
            Math::MPC::Rmpc_sub($quo, $x, $quo, $ROUND);

            return $quo;
        }

      Math_MPC__Scalar: {
            my $quo = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_div_ui($quo, $x, $y, $ROUND);

            my $real = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            my $imag = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            Math::MPC::RMPC_RE($real, $quo);
            Math::MPC::RMPC_IM($imag, $quo);

            Math::MPFR::Rmpfr_floor($real, $real);
            Math::MPFR::Rmpfr_floor($imag, $imag);

            Math::MPC::Rmpc_set_fr_fr($quo, $real, $imag, $ROUND);

            Math::MPC::Rmpc_mul_ui($quo, $quo, $y, $ROUND);
            Math::MPC::Rmpc_sub($quo, $x, $quo, $ROUND);

            return $quo;
        }

      Math_MPC__Math_MPFR: {
            $y = _mpfr2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Math_GMPz: {
            $y = _mpz2mpc($y);
            goto Math_MPC__Math_MPC;
        }

      Math_MPC__Math_GMPq: {
            $y = _mpq2mpc($y);
            goto Math_MPC__Math_MPC;
        }
    }

    sub mod {
        my ($x, $y) = @_;
        _valid(\$y);
        bless \__mod__($$x, $$y);
    }

    sub imod {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // (goto &nan);
        $y = _any2mpz($$y) // (goto &nan);

        my $sign_y = Math::GMPz::Rmpz_sgn($y)
          || goto &nan;

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_mod($r, $x, $y);

        if (!Math::GMPz::Rmpz_sgn($r)) {
            ## OK
        }
        elsif ($sign_y < 0) {
            Math::GMPz::Rmpz_add($r, $r, $y);
        }

        bless \$r;
    }

    sub modpow {
        my ($x, $y, $z) = @_;

        _valid(\$y, \$z);

        $x = _any2mpz($$x) // (goto &nan);
        $y = _any2mpz($$y) // (goto &nan);
        $z = _any2mpz($$z) // (goto &nan);

        Math::GMPz::Rmpz_sgn($z) || goto &nan;

        if (Math::GMPz::Rmpz_sgn($y) < 0) {
            my $t = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_gcd($t, $x, $z);
            Math::GMPz::Rmpz_cmp_ui($t, 1) == 0 or goto &nan;
        }

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_powm($r, $x, $y, $z);
        bless \$r;
    }

    *expmod = \&modpow;
    *powmod = \&modpow;

    sub modinv {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // (goto &nan);
        $y = _any2mpz($$y) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_invert($r, $x, $y) || (goto &nan);
        bless \$r;
    }

    *invmod = \&modinv;

    sub divmod {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // return (nan(), nan());
        $y = _any2mpz($$y) // return (nan(), nan());

        Math::GMPz::Rmpz_sgn($y)
          || return (nan(), nan());

        my $r = Math::GMPz::Rmpz_init();
        my $s = Math::GMPz::Rmpz_init();

        Math::GMPz::Rmpz_divmod($r, $s, $x, $y);
        ((bless \$r), (bless \$s));
    }

    sub and {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // (goto &nan);
        $y = _any2mpz($$y) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_and($r, $x, $y);
        bless \$r;
    }

    sub or {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // (goto &nan);
        $y = _any2mpz($$y) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_ior($r, $x, $y);
        bless \$r;
    }

    sub xor {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // (goto &nan);
        $y = _any2mpz($$y) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_xor($r, $x, $y);
        bless \$r;
    }

    sub not {
        my ($x) = @_;

        $x = _any2mpz($$x) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_com($r, $x);
        bless \$r;
    }

    sub ramanujan_tau {
        __PACKAGE__->_set_str('int', Math::Prime::Util::GMP::ramanujan_tau(&_big2uistr // (goto &nan)));
    }

    sub factorial {
        my ($x) = @_;
        my $ui = _any2ui($$x) // (goto &nan);
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_fac_ui($z, $ui);
        bless \$z;
    }

    *fac = \&factorial;

    sub double_factorial {
        my ($x) = @_;
        my $ui = _any2ui($$x) // (goto &nan);
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_2fac_ui($z, $ui);
        bless \$z;
    }

    *dfac       = \&double_factorial;
    *dfactorial = \&double_factorial;

    sub mfactorial {
        my ($x, $y) = @_;
        _valid(\$y);
        my $ui1 = _any2ui($$x) // (goto &nan);
        my $ui2 = _any2ui($$y) // (goto &nan);
        my $z   = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_mfac_uiui($z, $ui1, $ui2);
        bless \$z;
    }

    *mfac = \&mfactorial;

    sub primorial {
        my ($x) = @_;
        my $ui = _any2ui($$x) // (goto &nan);
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_primorial_ui($z, $ui);
        bless \$z;
    }

    sub pn_primorial {
        my ($x) = @_;
        __PACKAGE__->_set_str('int', Math::Prime::Util::GMP::pn_primorial(_any2ui($$x) // (goto &nan)));
    }

    sub lucas {
        my ($x) = @_;
        my $ui = _any2ui($$x) // (goto &nan);
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_lucnum_ui($z, $ui);
        bless \$z;
    }

    sub fibonacci {
        my ($x) = @_;
        my $ui = _any2ui($$x) // (goto &nan);
        my $z = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_fib_ui($z, $ui);
        bless \$z;
    }

    *fib = \&fibonacci;

    sub stirling {
        my ($x, $y) = @_;
        _valid(\$y);
        __PACKAGE__->_set_str('int',
                              Math::Prime::Util::GMP::stirling(_big2uistr($x) // (goto &nan), _big2uistr($y) // (goto &nan)));
    }

    sub stirling2 {
        my ($x, $y) = @_;
        _valid(\$y);
        __PACKAGE__->_set_str(
                              'int',
                              Math::Prime::Util::GMP::stirling(
                                                               _big2uistr($x) // (goto &nan), _big2uistr($y) // (goto &nan), 2
                                                              )
                             );
    }

    sub stirling3 {
        my ($x, $y) = @_;
        _valid(\$y);
        __PACKAGE__->_set_str(
                              'int',
                              Math::Prime::Util::GMP::stirling(
                                                               _big2uistr($x) // (goto &nan), _big2uistr($y) // (goto &nan), 3
                                                              )
                             );
    }

    sub bell {
        my ($x) = @_;
        my $n = _any2ui($$x) // goto &nan;
        __PACKAGE__->_set_str('int',
                              Math::Prime::Util::GMP::vecsum(map { Math::Prime::Util::GMP::stirling($n, $_, 2) } 0 .. $n));
    }

    sub binomial {
        my ($x, $y) = @_;
        _valid(\$y);

        $y = _any2si($$y)  // (goto &nan);
        $x = _any2mpz($$x) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();

        $y < 0
          ? Math::GMPz::Rmpz_bin_si($r, $x, $y)
          : Math::GMPz::Rmpz_bin_ui($r, $x, $y);

        bless \$r;
    }

    *nok = \&binomial;

    sub moebius {
        my $mob = Math::Prime::Util::GMP::moebius(&_big2istr // goto &nan);
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

    # Currently, this method is very slow for wide ranges.
    # It's included with the hope that it will become faster in the future.
    sub prime_count {
        my ($x, $y) = @_;
        my $n = defined($y)
          ? do {
            _valid(\$y);
            Math::Prime::Util::GMP::prime_count(_big2istr($x) // (goto &nan), _big2istr($y) // (goto &nan));
          }
          : Math::Prime::Util::GMP::prime_count(2, _big2istr($x) // (goto &nan));
        $n <= ULONG_MAX ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str('int', $n);
    }

    sub square_free_count {
        my ($from, $to) = @_;

        if (defined($to)) {
            _valid(\$to);
            return $to->square_free_count->sub($from->dec->square_free_count);
        }

        (my $n = __numify__($$from)) <= 0 && return ZERO;

        # Optimization for native integers
        if ($n <= ULONG_MAX) {

            $n = CORE::int($n);
            my $s = CORE::int(CORE::sqrt($n));

            # Using moebius(1, sqrt(n)) for values of n <= 2^40
            if ($n <= (1 << 40)) {

                my ($count, $k) = (0, 0);

                foreach my $m (Math::Prime::Util::GMP::moebius(1, $s)) {
                    ++$k;
                    if ($m) {
                        $count += $m * CORE::int($n / ($k * $k));
                    }
                }

                return __PACKAGE__->_set_uint($count);
            }

            # Linear counting up to sqrt(n)
            my ($count, $m) = 0;
            foreach my $k (1 .. $s) {
                if ($m = Math::Prime::Util::GMP::moebius($k)) {
                    $count += $m * CORE::int($n / ($k * $k));
                }
            }
            return __PACKAGE__->_set_uint($count);
        }

        # Implementation for large values of n
        my $c = Math::GMPz::Rmpz_init_set_ui(0);
        my $t = Math::GMPz::Rmpz_init();
        my $z = _any2mpz($$from) // return ZERO;

        my $s = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_sqrt($s, $z);

        for (my $k = Math::GMPz::Rmpz_init_set_ui(1) ; Math::GMPz::Rmpz_cmp($k, $s) <= 0 ; Math::GMPz::Rmpz_add_ui($k, $k, 1))
        {
            my $m = Math::Prime::Util::GMP::moebius(Math::GMPz::Rmpz_get_str($k, 10));

            if ($m) {
                Math::GMPz::Rmpz_set($t, $z);
                Math::GMPz::Rmpz_tdiv_q($t, $t, $k);
                Math::GMPz::Rmpz_tdiv_q($t, $t, $k);
                ($m == -1)
                  ? Math::GMPz::Rmpz_sub($c, $c, $t)
                  : Math::GMPz::Rmpz_add($c, $c, $t);
            }
        }

        bless \$c;
    }

    sub _Li_inverse {
        my ($x) = @_;

        # Function translated from:
        #   https://github.com/kimwalisch/primecount

        my $logx  = CORE::log($x);
        my $first = CORE::int($x * $logx);
        my $last  = CORE::int($x * $logx * 2 + 2);

        my $mpfr = Math::MPFR::Rmpfr_init2(64);

        # Find Li^-1(x) using binary search
        while ($first < $last) {
            my $mid = $first + (($last - $first) >> 1);

            Math::MPFR::Rmpfr_set_d($mpfr, CORE::log($mid), $ROUND);
            Math::MPFR::Rmpfr_eint($mpfr, $mpfr, $ROUND);

            if (Math::MPFR::Rmpfr_get_d($mpfr, $ROUND) - 1.045163780117 < $x) {
                $first = $mid + 1;
            }
            else {
                $last = $mid;
            }
        }

        return $first;
    }

    sub nth_prime {
        my ($n) = @_;

        $n = _any2ui($$n) // goto &nan;

        if ($n == 0) {
            return ONE;    # not a prime, but it's convenient...
        }

        if ($n > 100_000) {

            my $i          = 2;
            my $count      = 0;
            my $prev_count = 0;

            #my $approx    = CORE::int($n * CORE::log($n) + $n * (CORE::log(CORE::log($n)) - 1));
            #my $up_approx = CORE::int($n * CORE::log($n) + $n * CORE::log(CORE::log($n)));

            my $li_inv_n  = _Li_inverse($n);
            my $li_inv_sn = _Li_inverse(CORE::int(CORE::sqrt($n)));

            ## Formula due to Dana Jacobsen:
            ## Nth prime ≈ Li^-1(n) + Li^-1(sqrt(n)) / 4
            my $approx    = CORE::int($li_inv_n + $li_inv_sn / 4);
            my $up_approx = CORE::int($li_inv_n + $li_inv_sn);       # conjecture

            state $checkpoints = [[1000000000000, 37607912018],
                                  [100000000000,  4118054813],
                                  [50000000000,   2119654578],
                                  [45000000000,   1916268743],
                                  [40000000000,   1711955433],
                                  [35000000000,   1506589876],
                                  [30000000000,   1300005926],
                                  [25000000000,   1091987405],
                                  [22000000000,   966358351],
                                  [21000000000,   924324489],
                                  [20000000000,   882206716],
                                  [19000000000,   840000027],
                                  [18000000000,   797703398],
                                  [17000000000,   755305935],
                                  [16000000000,   712799821],
                                  [15000000000,   670180516],
                                  [14000000000,   627440336],
                                  [13000000000,   584570200],
                                  [12000000000,   541555851],
                                  [11000000000,   498388617],
                                  [10000000000,   455052511],
                                  [9900000000,    450708777],
                                  [9700000000,    442014876],
                                  [9500000000,    433311792],
                                  [9300000000,    424603409],
                                  [9000000000,    411523195],
                                  [8700000000,    398425675],
                                  [8500000000,    389682427],
                                  [8300000000,    380930729],
                                  [8000000000,    367783654],
                                  [7500000000,    345826612],
                                  [7300000000,    337024801],
                                  [7000000000,    323804352],
                                  [6700000000,    310558733],
                                  [6500000000,    301711468],
                                  [6400000000,    297285198],
                                  [6300000000,    292856421],
                                  [6000000000,    279545368],
                                  [5700000000,    266206294],
                                  [5500000000,    257294520],
                                  [5300000000,    248370960],
                                  [5200000000,    243902342],
                                  [5000000000,    234954223],
                                  [4900000000,    230475545],
                                  [4700000000,    221504167],
                                  [4500000000,    212514323],
                                  [4300000000,    203507248],
                                  [4200000000,    198996103],
                                  [4000000000,    189961812],
                                  [3900000000,    185436625],
                                  [3800000000,    180906194],
                                  [3700000000,    176369517],
                                  [3500000000,    167279333],
                                  [3400000000,    162725196],
                                  [3300000000,    158165829],
                                  [3100000000,    149028641],
                                  [3000000000,    144449537],
                                  [2900000000,    139864011],
                                  [2800000000,    135270258],
                                  [2700000000,    130670192],
                                  [2600000000,    126062167],
                                  [2500000000,    121443371],
                                  [2400000000,    116818447],
                                  [2200000000,    107540122],
                                  [2000000000,    98222287],
                                  [1900000000,    93547928],
                                  [1800000000,    88862422],
                                  [1700000000,    84163019],
                                  [1600000000,    79451833],
                                  [1500000000,    74726528],
                                  [1400000000,    69985473],
                                  [1300000000,    65228333],
                                  [1200000000,    60454705],
                                  [1100000000,    55662470],
                                  [1000000000,    50847534],
                                  [950000000,     48431471],
                                  [900000000,     46009215],
                                  [850000000,     43581966],
                                  [800000000,     41146179],
                                  [750000000,     38703181],
                                  [700000000,     36252931],
                                  [650000000,     33793395],
                                  [600000000,     31324703],
                                  [550000000,     28845356],
                                  [500000000,     26355867],
                                  [450000000,     23853038],
                                  [400000000,     21336326],
                                  [370000000,     19818405],
                                  [360000000,     19311288],
                                  [350000000,     18803526],
                                  [330000000,     17785475],
                                  [300000000,     16252325],
                                  [290000000,     15739663],
                                  [270000000,     14711384],
                                  [250000000,     13679318],
                                  [230000000,     12642573],
                                  [200000000,     11078937],
                                  [190000000,     10555473],
                                  [170000000,     9503083],
                                  [160000000,     8974458],
                                  [150000000,     8444396],
                                  [140000000,     7912199],
                                  [120000000,     6841648],
                                  [100000000,     5761455],
                                  [95000000,      5489749],
                                  [90000000,      5216954],
                                  [85000000,      4943731],
                                  [80000000,      4669382],
                                  [75000000,      4394304],
                                  [70000000,      4118064],
                                  [65000000,      3840554],
                                  [60000000,      3562115],
                                  [55000000,      3282200],
                                  [50000000,      3001134],
                                  [45000000,      2718160],
                                  [40000000,      2433654],
                                  [35000000,      2146775],
                                  [30000000,      1857859],
                                  [25000000,      1565927],
                                  [20000000,      1270607],
                                  [19000000,      1211050],
                                  [18000000,      1151367],
                                  [17000000,      1091314],
                                  [16000000,      1031130],
                                  [15000000,      970704],
                                  [14000000,      910077],
                                  [13000000,      849252],
                                  [12000000,      788060],
                                  [11000000,      726517],
                                  [10000000,      664579],
                                  [9000000,       602489],
                                  [8000000,       539777],
                                  [7000000,       476648],
                                  [6000000,       412849],
                                  [5000000,       348513],
                                  [4000000,       283146],
                                  [3000000,       216816],
                                  [2000000,       148933],
                                  [1000000,       78498],
                                 ];

            {
                state $end = $#{$checkpoints};

                my $left  = 0;
                my $right = $end;

                my ($middle, $item, $cmp);

                while (1) {
                    $middle = (($right + $left) >> 1);
                    $item   = $checkpoints->[$middle][0];
                    $cmp    = ($approx <=> $item) || last;

                    if ($cmp < 0) {
                        $left = $middle + 1;
                        if ($left > $right) {
                            ++$middle;
                            last;
                        }
                    }
                    else {
                        $right = $middle - 1;
                        $left > $right && last;
                    }
                }

                my $point = $checkpoints->[$middle];

                $count      = $point->[1];
                $i          = $point->[0];
                $prev_count = $count;
            }

            my $count_approx = $up_approx - $i;
            my $step = $count_approx < 1e6 ? $count_approx : $n > 1e8 ? 1e7 : 1e6;

            for (; ; $i += $step) {
                my @primes = Math::Prime::Util::GMP::sieve_primes($i, $i + $step);
                $count += @primes;

                if ($count >= $n) {
                    my $p = $primes[$n - $prev_count - 1];
                    return __PACKAGE__->_set_str('int', $p);
                }

                $prev_count = $count;
            }
        }

        state $table = [Math::Prime::Util::GMP::sieve_primes(2, 1_299_709)];    # primes up to prime(100_000)
        __PACKAGE__->_set_uint($table->[$n - 1]);
    }

    *prime = \&nth_prime;

    sub legendre {
        my ($x, $y) = @_;
        _valid(\$y);

        my $sym = Math::GMPz::Rmpz_legendre(_any2mpz($$x) // (goto &nan), _any2mpz($$y) // (goto &nan));

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

        my $sym = Math::GMPz::Rmpz_jacobi(_any2mpz($$x) // (goto &nan), _any2mpz($$y) // (goto &nan));

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

        my $sym = Math::GMPz::Rmpz_kronecker(_any2mpz($$x) // (goto &nan), _any2mpz($$y) // (goto &nan));

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

    sub is_coprime {
        my ($x, $y) = @_;

        _valid(\$y);

        (__is_int__($$x) && __is_int__($$y))
          || return Sidef::Types::Bool::Bool::FALSE;

        $x = _any2mpz($$x) // return Sidef::Types::Bool::Bool::FALSE;
        $y = _any2mpz($$y) // return Sidef::Types::Bool::Bool::FALSE;

        state $t = Math::GMPz::Rmpz_init_nobless();
        Math::GMPz::Rmpz_gcd($t, $x, $y);

        (Math::GMPz::Rmpz_cmp_ui($t, 1) == 0)
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub gcd {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // goto &nan;
        $y = _any2mpz($$y) // goto &nan;

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_gcd($r, $x, $y);
        bless \$r;
    }

    sub lcm {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // goto &nan;
        $y = _any2mpz($$y) // goto &nan;

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_lcm($r, $x, $y);
        bless \$r;
    }

    sub valuation {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // goto &nan;
        $y = _any2mpz($$y) // goto &nan;

        Math::GMPz::Rmpz_sgn($y) || return ZERO;
        Math::GMPz::Rmpz_cmpabs_ui($y, 1) || return ZERO;

        state $t = Math::GMPz::Rmpz_init_nobless();
        __PACKAGE__->_set_uint(scalar Math::GMPz::Rmpz_remove($t, $x, $y));
    }

    sub remove {
        my ($x, $y) = @_;

        _valid(\$y);

        $x = _any2mpz($$x) // goto &nan;
        $y = _any2mpz($$y) // goto &nan;

        Math::GMPz::Rmpz_sgn($y) || return $_[0];
        Math::GMPz::Rmpz_cmpabs_ui($y, 1) || return $_[0];

        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_remove($r, $x, $y);
        bless \$r;
    }

    *remdiv = \&remove;

    sub make_coprime {
        my ($x, $y) = @_;

        _valid(\$y);
        my $r = Math::GMPz::Rmpz_init_set(_any2mpz($$x) // goto &nan);

        my %factors;
        @factors{Math::Prime::Util::GMP::factor(_big2uistr($y) // goto &nan)} = ();

        my $t = Math::GMPz::Rmpz_init();
        foreach my $f (keys %factors) {
            if ($f <= ULONG_MAX) {
                Math::GMPz::Rmpz_divisible_ui_p($r, $f)
                  ? Math::GMPz::Rmpz_set_ui($t, $f)
                  : next;
            }
            else {
                Math::GMPz::Rmpz_set_str($t, $f);
            }
            Math::GMPz::Rmpz_remove($r, $r, $t);
        }

        bless \$r;
    }

    sub random_prime {
        my ($from, $to) = @_;

        my $prime;
        if (defined($to)) {
            _valid(\$to);
            $prime = Math::Prime::Util::GMP::random_prime(_big2uistr($from) // (goto &nan), _big2uistr($to) // (goto &nan));
        }
        else {
            $prime = Math::Prime::Util::GMP::random_prime(2, _big2uistr($from) // (goto &nan));
        }

        __PACKAGE__->_set_str('int', $prime // goto &nan);
    }

    sub random_nbit_prime {
        my ($x) = @_;
        my $n = _any2ui($$x) // goto &nan;
        $n <= 1 && goto &nan;
        __PACKAGE__->_set_str('int', Math::Prime::Util::GMP::random_nbit_prime($n));
    }

    sub random_ndigit_prime {
        my ($x) = @_;
        my $n = _any2ui($$x) || goto &nan;
        __PACKAGE__->_set_str('int', Math::Prime::Util::GMP::random_ndigit_prime($n));
    }

    sub is_semiprime {
        my ($x) = @_;
        __is_int__($$x)
          && Math::Prime::Util::GMP::is_semiprime(&_big2uistr // return Sidef::Types::Bool::Bool::FALSE)
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_prime {
        my ($x) = @_;
        __is_int__($$x)
          && Math::Prime::Util::GMP::is_prime(&_big2uistr // return Sidef::Types::Bool::Bool::FALSE)
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_prob_prime {
        my ($x, $k) = @_;

        my $z = $$x;
        if (defined($k)) {
            _valid(\$k);
            (__is_int__($z) and Math::GMPz::Rmpz_probab_prime_p(_any2mpz($z), CORE::abs(_any2si($$k) // 20)) > 0)
              ? Sidef::Types::Bool::Bool::TRUE
              : Sidef::Types::Bool::Bool::FALSE;
        }
        else {
            __is_int__($z)
              && Math::Prime::Util::GMP::is_prob_prime(_big2uistr($x) // return Sidef::Types::Bool::Bool::FALSE)
              ? Sidef::Types::Bool::Bool::TRUE
              : Sidef::Types::Bool::Bool::FALSE;
        }
    }

    sub is_prov_prime {
        my ($x) = @_;
        __is_int__($$x)
          && Math::Prime::Util::GMP::is_provable_prime(_big2uistr($x) // return Sidef::Types::Bool::Bool::FALSE)
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_mersenne_prime {
        my ($x) = @_;
        __is_int__($$x)
          && Math::Prime::Util::GMP::is_mersenne_prime(_big2uistr($x) // return Sidef::Types::Bool::Bool::FALSE)
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub primes {
        my ($x, $y) = @_;

        _valid(\$y) if defined($y);

        Sidef::Types::Array::Array->new(
            [
             map {
                 $_ <= ULONG_MAX
                   ? __PACKAGE__->_set_uint($_)
                   : __PACKAGE__->_set_str('int', $_)
               }

               defined($y)
             ? Math::Prime::Util::GMP::sieve_primes((_big2uistr($x) // 0), (_big2uistr($y) // 0), 0)
             : Math::Prime::Util::GMP::sieve_primes(2, (_big2uistr($x) // 0), 0)
            ]
        );
    }

    sub prev_prime {
        my $p = Math::Prime::Util::GMP::prev_prime(&_big2uistr // goto &nan) || goto &nan;
        $p <= ULONG_MAX ? __PACKAGE__->_set_uint($p) : __PACKAGE__->_set_str('int', $p);
    }

    sub next_prime {
        my ($x) = @_;
        $x = _any2mpz($$x) // goto &nan;
        my $r = Math::GMPz::Rmpz_init();
        Math::GMPz::Rmpz_nextprime($r, $x);
        bless \$r;
    }

    sub znorder {
        my ($x, $y) = @_;
        _valid(\$y);
        my $z = Math::Prime::Util::GMP::znorder(_big2uistr($x) // (goto &nan), _big2uistr($y) // (goto &nan)) // goto &nan;
        $z <= ULONG_MAX ? __PACKAGE__->_set_uint($z) : __PACKAGE__->_set_str('int', $z);
    }

    sub znprimroot {
        my $z = Math::Prime::Util::GMP::znprimroot(&_big2uistr // (goto &nan)) // goto &nan;
        $z <= ULONG_MAX ? __PACKAGE__->_set_uint($z) : __PACKAGE__->_set_str('int', $z);
    }

    sub rad {
        my %f;
        @f{Math::Prime::Util::GMP::factor(&_big2uistr // goto &nan)} = ();
        my $r = Math::Prime::Util::GMP::vecprod(CORE::keys %f);
        $r <= ULONG_MAX ? __PACKAGE__->_set_uint($r) : __PACKAGE__->_set_str('int', $r);
    }

    sub factor {
        Sidef::Types::Array::Array->new(
            [
             map {
                 $_ <= ULONG_MAX
                   ? __PACKAGE__->_set_uint($_)
                   : __PACKAGE__->_set_str('int', $_)
               }

               Math::Prime::Util::GMP::factor(&_big2uistr || return Sidef::Types::Array::Array->new())
            ]
        );
    }

    *factors = \&factor;

    sub factor_exp {
        my %count;
        foreach my $f (Math::Prime::Util::GMP::factor(&_big2uistr || return Sidef::Types::Array::Array->new())) {
            ++$count{$f};
        }

        my @pairs;
        foreach my $factor (sort { (CORE::length($a) <=> CORE::length($b)) || ($a cmp $b) } keys(%count)) {
            push @pairs,
              Sidef::Types::Array::Array->new(
                                              [
                                               (
                                                $factor <= ULONG_MAX
                                                ? __PACKAGE__->_set_uint($factor)
                                                : __PACKAGE__->_set_str('int', $factor)
                                               ),
                                               __PACKAGE__->_set_uint($count{$factor})
                                              ]
                                             );
        }

        Sidef::Types::Array::Array->new(\@pairs);
    }

    *factors_exp = \&factor_exp;

    sub divisors {
        my $n = &_big2uistr || return Sidef::Types::Array::Array->new();

        Sidef::Types::Array::Array->new(
            [
             map {
                 $_ <= ULONG_MAX
                   ? __PACKAGE__->_set_uint($_)
                   : __PACKAGE__->_set_str('int', $_)
               } Math::Prime::Util::GMP::divisors($n)
            ]
        );
    }

    sub exp_mangoldt {
        my $n = Math::Prime::Util::GMP::exp_mangoldt(&_big2uistr || return ONE);
        $n eq '1' and return ONE;
        $n <= ULONG_MAX ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str('int', $n);
    }

    sub totient {
        my $n = Math::Prime::Util::GMP::totient(&_big2uistr // goto &nan);
        $n <= ULONG_MAX ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str('int', $n);
    }

    *euler_phi     = \&totient;
    *euler_totient = \&totient;

    sub jordan_totient {
        my ($x, $y) = @_;
        _valid(\$y);
        my $n = Math::Prime::Util::GMP::jordan_totient(_big2istr($x) // (goto &nan), _big2istr($y) // (goto &nan));
        $n <= ULONG_MAX ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str('int', $n);
    }

    sub carmichael_lambda {
        my $n = Math::Prime::Util::GMP::carmichael_lambda(&_big2uistr // goto &nan);
        $n <= ULONG_MAX ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str('int', $n);
    }

    sub liouville {
        Math::Prime::Util::GMP::liouville(&_big2uistr // goto &nan) == 1 ? ONE : MONE;
    }

    sub big_omega {
        __PACKAGE__->_set_uint(scalar Math::Prime::Util::GMP::factor(&_big2uistr // goto &nan));
    }

    sub omega {
        my %factors;
        @factors{Math::Prime::Util::GMP::factor(&_big2uistr // goto &nan)} = ();
        __PACKAGE__->_set_uint(scalar keys %factors);
    }

    sub sigma0 {
        my $str = &_big2uistr // goto &nan;
        $str eq '0' && return ZERO;
        my $n = Math::Prime::Util::GMP::sigma($str, 0);
        $n <= ULONG_MAX ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str('int', $n);
    }

    sub sigma {
        my ($x, $y) = @_;

        my $n = defined($y)
          ? do {
            _valid(\$y);
            Math::Prime::Util::GMP::sigma(_big2uistr($x) // (goto &nan), _big2uistr($y) // (goto &nan));
          }
          : Math::Prime::Util::GMP::sigma(&_big2uistr // (goto &nan), 1);

        $n <= ULONG_MAX ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str('int', $n);
    }

    sub partitions {
        my $n = Math::Prime::Util::GMP::partitions(&_big2uistr // goto &nan);
        $n <= ULONG_MAX ? __PACKAGE__->_set_uint($n) : __PACKAGE__->_set_str('int', $n);
    }

    sub is_primitive_root {
        my ($x, $y) = @_;
        _valid(\$y);
        __is_int__($$x)
          && __is_int__($$y)
          && Math::Prime::Util::GMP::is_primitive_root(_big2uistr($x) // (return Sidef::Types::Bool::Bool::FALSE),
                                                       _big2uistr($y) // (return Sidef::Types::Bool::Bool::FALSE))
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_square_free {
        my ($x) = @_;
        __is_int__($$x)
          && Math::Prime::Util::GMP::moebius(_big2uistr($x) // return Sidef::Types::Bool::Bool::FALSE)
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_smooth {
        my ($x, $n) = @_;

        _valid(\$n);
        __is_int__($$x) || return Sidef::Types::Bool::Bool::FALSE;

        $x = _any2mpz($$x) // return Sidef::Types::Bool::Bool::FALSE;
        $n = _any2mpz($$n) // return Sidef::Types::Bool::Bool::FALSE;

        Math::GMPz::Rmpz_sgn($n) <= 0
          and return Sidef::Types::Bool::Bool::FALSE;

        my $p = Math::GMPz::Rmpz_init_set_ui(2);
        my $t = Math::GMPz::Rmpz_init_set($x);

        while (Math::GMPz::Rmpz_cmp($p, $n) <= 0) {
            if (Math::GMPz::Rmpz_divisible_p($t, $p)) {
                Math::GMPz::Rmpz_remove($t, $t, $p);
                Math::GMPz::Rmpz_cmp_ui($t, 1) == 0
                  and return Sidef::Types::Bool::Bool::TRUE;
            }
            Math::GMPz::Rmpz_nextprime($p, $p);
        }

        (Math::GMPz::Rmpz_cmp_ui($t, 1) == 0)
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub is_square {
        my ($x) = @_;
        __is_int__($$x)
          && Math::GMPz::Rmpz_perfect_square_p(_any2mpz($$x))
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    *is_sqr = \&is_square;

    sub is_power {
        my ($x, $y) = @_;

        __is_int__($$x) || return Sidef::Types::Bool::Bool::FALSE;
        $x = _any2mpz($$x) // return Sidef::Types::Bool::Bool::FALSE;

        if (defined $y) {
            _valid(\$y);

            if (Math::GMPz::Rmpz_cmp_ui($x, 1) == 0) {
                return Sidef::Types::Bool::Bool::TRUE;
            }

            $y = _any2si($$y) // return undef;

            # Everything is a first power
            $y == 1 and return Sidef::Types::Bool::Bool::TRUE;

            # Return a true value when $x=-1 and $y is odd
            $y % 2
              and (Math::GMPz::Rmpz_cmp_si($x, -1) == 0)
              and return Sidef::Types::Bool::Bool::TRUE;

            # Don't accept a non-positive power
            # Also, when $x is negative and $y is even, return faster
            if ($y <= 0 or ($y % 2 == 0 and Math::GMPz::Rmpz_sgn($x) < 0)) {
                return Sidef::Types::Bool::Bool::FALSE;
            }

            # Optimization for perfect squares (thanks to Dana Jacobsen)
            $y == 2
              and return (
                          Math::GMPz::Rmpz_perfect_square_p($x)
                          ? Sidef::Types::Bool::Bool::TRUE
                          : Sidef::Types::Bool::Bool::FALSE
                         );

            Math::GMPz::Rmpz_perfect_power_p($x)
              || return Sidef::Types::Bool::Bool::FALSE;

            state $t = Math::GMPz::Rmpz_init_nobless();
            Math::GMPz::Rmpz_root($t, $x, $y)
              ? Sidef::Types::Bool::Bool::TRUE
              : Sidef::Types::Bool::Bool::FALSE;
        }
        else {
            Math::GMPz::Rmpz_perfect_power_p($x)
              ? Sidef::Types::Bool::Bool::TRUE
              : Sidef::Types::Bool::Bool::FALSE;
        }
    }

    *is_pow = \&is_power;

    sub is_prime_power {
        my ($x) = @_;
        __is_int__($$x)
          && Math::Prime::Util::GMP::is_prime_power(_big2uistr($x) // return Sidef::Types::Bool::Bool::FALSE)
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub prime_root {
        my $str = &_big2uistr // return $_[0];

        my $pow = Math::Prime::Util::GMP::is_prime_power($str) || return $_[0];
        $pow == 1 and return $_[0];

        my $x = Math::GMPz::Rmpz_init_set_str($str, 10);
        $pow == 2
          ? Math::GMPz::Rmpz_sqrt($x, $x)
          : Math::GMPz::Rmpz_root($x, $x, $pow);
        bless \$x;
    }

    sub prime_power {
        my $pow = Math::Prime::Util::GMP::is_prime_power(&_big2uistr // return ONE) || return ONE;
        $pow == 1 ? ONE : __PACKAGE__->_set_uint($pow);
    }

    sub perfect_root {
        my $str = &_big2istr // return $_[0];
        my $pow = Math::Prime::Util::GMP::is_power($str) || return $_[0];

        my $x = Math::GMPz::Rmpz_init_set_str($str, 10);
        $pow == 2
          ? Math::GMPz::Rmpz_sqrt($x, $x)
          : Math::GMPz::Rmpz_root($x, $x, $pow);
        bless \$x;
    }

    sub perfect_power {
        __PACKAGE__->_set_uint(Math::Prime::Util::GMP::is_power(&_big2istr // return ONE) || return ONE);
    }

    sub next_pow2 {
        my ($x) = @_;

        my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

        Math::MPFR::Rmpfr_log2($r, _any2mpfr($$x), Math::MPFR::MPFR_RNDZ);
        Math::MPFR::Rmpfr_ceil($r, $r);

        my $z = Math::GMPz::Rmpz_init_set_ui(1);
        my $ui = Math::MPFR::Rmpfr_get_ui($r, $ROUND);
        Math::GMPz::Rmpz_mul_2exp($z, $z, $ui);
        bless \$z;
    }

    *next_power2 = \&next_pow2;

    sub next_pow {
        my ($x, $y) = @_;

        _valid(\$y);

        my $f1 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        my $f2 = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

        Math::MPFR::Rmpfr_log($f1, _any2mpfr($$x), Math::MPFR::MPFR_RNDZ);
        Math::MPFR::Rmpfr_log($f2, _any2mpfr($$y), Math::MPFR::MPFR_RNDZ);

        Math::MPFR::Rmpfr_div($f1, $f1, $f2, $ROUND);
        Math::MPFR::Rmpfr_ceil($f1, $f1);

        my $r = Math::GMPz::Rmpz_init();
        my $ui = Math::MPFR::Rmpfr_get_ui($f1, $ROUND);
        Math::GMPz::Rmpz_pow_ui($r, (_any2mpz($$y) // goto &nan), $ui);
        bless \$r;
    }

    *next_power = \&next_pow;

    sub shift_left {
        my ($x, $y) = @_;

        _valid(\$y);

        $y = _any2si($$y)  // (goto &nan);
        $x = _any2mpz($$x) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();

        $y < 0
          ? Math::GMPz::Rmpz_div_2exp($r, $x, -$y)
          : Math::GMPz::Rmpz_mul_2exp($r, $x, $y);

        bless \$r;
    }

    *lsft = \&shift_left;

    sub shift_right {
        my ($x, $y) = @_;

        _valid(\$y);

        $y = _any2si($$y)  // (goto &nan);
        $x = _any2mpz($$x) // (goto &nan);

        my $r = Math::GMPz::Rmpz_init();

        $y < 0
          ? Math::GMPz::Rmpz_mul_2exp($r, $x, -$y)
          : Math::GMPz::Rmpz_div_2exp($r, $x, $y);

        bless \$r;
    }

    *rsft = \&shift_right;

    #
    ## Rational specific
    #

    sub numerator {
        my ($x) = @_;

        my $r = $$x;
        while (1) {
            my $ref = ref($r);
            ref($r) eq 'Math::GMPz' && return $x;    # is an integer

            if (ref($r) eq 'Math::GMPq') {
                my $z = Math::GMPz::Rmpz_init();
                Math::GMPq::Rmpq_get_num($z, $r);
                return bless \$z;
            }

            $r = _any2mpq($r) // (goto &nan);
        }
    }

    *nu = \&numerator;

    sub denominator {
        my ($x) = @_;

        my $r = $$x;
        while (1) {
            my $ref = ref($r);
            ref($r) eq 'Math::GMPz' && return ONE;    # is an integer

            if (ref($r) eq 'Math::GMPq') {
                my $z = Math::GMPz::Rmpz_init();
                Math::GMPq::Rmpq_get_den($z, $r);
                return bless \$z;
            }

            $r = _any2mpq($r) // (goto &nan);
        }
    }

    *de = \&denominator;

    sub nude {
        ($_[0]->numerator, $_[0]->denominator);
    }

    #
    ## Conversion/Miscellaneous
    #

    sub chr {
        my ($x) = @_;
        Sidef::Types::String::String->new(CORE::chr(__numify__($$x)));
    }

    sub __round__ {
        my ($x, $prec) = @_;

        goto(ref($x) =~ tr/:/_/rs);

      Math_MPFR: {
            my $nth = -CORE::int($prec);

            my $p = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            Math::MPFR::Rmpfr_set_str($p, '1e' . CORE::abs($nth), 10, $ROUND);

            my $r = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            if ($nth < 0) {
                Math::MPFR::Rmpfr_div($r, $x, $p, $ROUND);
            }
            else {
                Math::MPFR::Rmpfr_mul($r, $x, $p, $ROUND);
            }

            Math::MPFR::Rmpfr_round($r, $r);

            if ($nth < 0) {
                Math::MPFR::Rmpfr_mul($r, $r, $p, $ROUND);
            }
            else {
                Math::MPFR::Rmpfr_div($r, $r, $p, $ROUND);
            }

            return $r;
        }

      Math_MPC: {
            my $real = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
            my $imag = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

            Math::MPC::RMPC_RE($real, $x);
            Math::MPC::RMPC_IM($imag, $x);

            $real = __SUB__->($real, $prec);
            $imag = __SUB__->($imag, $prec);

            if (Math::MPFR::Rmpfr_zero_p($imag)) {
                return $real;
            }

            my $r = Math::MPC::Rmpc_init2(CORE::int($PREC));
            Math::MPC::Rmpc_set_fr_fr($r, $real, $imag, $ROUND);
            return $r;
        }

      Math_GMPq: {
            my $nth = -CORE::int($prec);

            my $r = Math::GMPq::Rmpq_init();
            Math::GMPq::Rmpq_set($r, $x);

            my $sgn = Math::GMPq::Rmpq_sgn($r);

            if ($sgn < 0) {
                Math::GMPq::Rmpq_neg($r, $r);
            }

            my $p = Math::GMPz::Rmpz_init_set_str('1' . ('0' x CORE::abs($nth)), 10);

            if ($nth < 0) {
                Math::GMPq::Rmpq_div_z($r, $r, $p);
            }
            else {
                Math::GMPq::Rmpq_mul_z($r, $r, $p);
            }

            state $half = do {
                my $q = Math::GMPq::Rmpq_init_nobless();
                Math::GMPq::Rmpq_set_ui($q, 1, 2);
                $q;
            };

            Math::GMPq::Rmpq_add($r, $r, $half);

            my $z = Math::GMPz::Rmpz_init();
            Math::GMPz::Rmpz_set_q($z, $r);

            if (Math::GMPz::Rmpz_odd_p($z) and Math::GMPq::Rmpq_integer_p($r)) {
                Math::GMPz::Rmpz_sub_ui($z, $z, 1);
            }

            Math::GMPq::Rmpq_set_z($r, $z);

            if ($nth < 0) {
                Math::GMPq::Rmpq_mul_z($r, $r, $p);
            }
            else {
                Math::GMPq::Rmpq_div_z($r, $r, $p);
            }

            if ($sgn < 0) {
                Math::GMPq::Rmpq_neg($r, $r);
            }

            if (Math::GMPq::Rmpq_integer_p($r)) {
                Math::GMPz::Rmpz_set_q($z, $r);
                return $z;
            }

            return $r;
        }

      Math_GMPz: {
            $x = _mpz2mpq($x);
            goto Math_GMPq;
        }
    }

    sub round {
        my ($x, $prec) = @_;

        my $nth = (
            defined($prec)
            ? do {
                _valid(\$prec);
                _any2si($$prec) // (goto &nan);
              }
            : 0
        );

        bless \__round__($$x, $nth);
    }

    *roundf = \&round;

    sub to {
        my ($from, $to, $step) = @_;
        Sidef::Types::Range::RangeNumber->new($from, $to, $step // ONE);
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
        my $srand = srand();

        {
            state $state = Math::MPFR::Rmpfr_randinit_mt_nobless();
            Math::MPFR::Rmpfr_randseed_ui($state, $srand);

            sub rand {
                my ($x, $y) = @_;

                my $rand = Math::MPFR::Rmpfr_init2(CORE::int($PREC));

                if (defined($y)) {
                    _valid(\$y);
                    Math::MPFR::Rmpfr_urandom($rand, $state, $ROUND);
                    $rand = __mul__($rand, __sub__($$y, $$x));
                    $rand = __add__($rand, $$x);
                }
                else {
                    Math::MPFR::Rmpfr_urandom($rand, $state, $ROUND);
                    $rand = __mul__($rand, $$x);
                }
                bless \$rand;
            }

            sub seed {
                my ($x) = @_;
                my $z = _any2mpz($$x) // die "[ERROR] Number.seed(): invalid seed value <<$x>> (expected an integer)";
                Math::MPFR::Rmpfr_randseed($state, $z);
                bless \$z;
            }
        }

        {
            state $state = Math::GMPz::zgmp_randinit_mt_nobless();
            Math::GMPz::zgmp_randseed_ui($state, $srand);

            sub irand {
                my ($x, $y) = @_;

                if (defined($y)) {
                    _valid(\$y);

                    $x = _any2mpz($$x) // goto &nan;
                    $y = _any2mpz($$y) // goto &nan;

                    my $cmp = Math::GMPz::Rmpz_cmp($y, $x);

                    if ($cmp == 0) {
                        return $_[0];
                    }
                    elsif ($cmp < 0) {
                        ($x, $y) = ($y, $x);
                    }

                    my $r = Math::GMPz::Rmpz_init();
                    Math::GMPz::Rmpz_sub($r, $y, $x);
                    Math::GMPz::Rmpz_add_ui($r, $r, 1);
                    Math::GMPz::Rmpz_urandomm($r, $state, $r, 1);
                    Math::GMPz::Rmpz_add($r, $r, $x);
                    return bless \$r;
                }

                $x = Math::GMPz::Rmpz_init_set(_any2mpz($$x) // goto &nan);

                my $sgn = Math::GMPz::Rmpz_sgn($x)
                  || return ZERO;

                if ($sgn < 0) {
                    Math::GMPz::Rmpz_sub_ui($x, $x, 1);
                }
                else {
                    Math::GMPz::Rmpz_add_ui($x, $x, 1);
                }

                Math::GMPz::Rmpz_urandomm($x, $state, $x, 1);
                Math::GMPz::Rmpz_neg($x, $x) if $sgn < 0;
                bless \$x;
            }

            sub iseed {
                my ($x) = @_;
                my $z = _any2mpz($$x) // die "[ERROR] Number.iseed(): invalid seed value <<$x>> (expected an integer)";
                Math::GMPz::zgmp_randseed($state, $z);
                bless \$z;
            }
        }
    }

    sub of {
        my ($x, $obj) = @_;

        $x = CORE::int(__numify__($$x));

        if (ref($obj) eq 'Sidef::Types::Block::Block') {
            my @array;
            for (my $i = 0 ; $i < $x ; ++$i) {
                push @array,
                  $obj->run(
                            $i <= 8192
                            ? __PACKAGE__->_set_uint($i)
                            : bless \Math::GMPz::Rmpz_init_set_ui($i)
                           );
            }
            return Sidef::Types::Array::Array->new(\@array);
        }

        Sidef::Types::Array::Array->new([($obj) x $x]);
    }

    sub defs {
        my ($x, $block) = @_;

        my @items;
        my $end = CORE::int(__numify__($$x));

        for (my ($i, $j) = (0, 0) ; $j < $end ; ++$i) {
            push @items,
              $block->run(
                          $i <= 8192
                          ? __PACKAGE__->_set_uint($i)
                          : bless \Math::GMPz::Rmpz_init_set_ui($i)
                         ) // next;
            ++$j;
        }

        Sidef::Types::Array::Array->new(\@items);
    }

    sub times {
        my ($num, $block) = @_;

        if (__is_inf__($$num)) {
            for (my $i = 0 ; ; ++$i) {
                $block->run(
                            $i <= 8192
                            ? __PACKAGE__->_set_uint($i)
                            : bless \Math::GMPz::Rmpz_init_set_ui($i)
                           );
            }
            return $_[0];
        }

        $num = _any2mpz($$num) // return undef;

        if (defined(my $ui = _any2ui($num))) {
            for (my $i = 0 ; $i < $ui ; ++$i) {
                $block->run(
                            $i <= 8192
                            ? __PACKAGE__->_set_uint($i)
                            : bless \Math::GMPz::Rmpz_init_set_ui($i)
                           );
            }
            return $_[0];
        }

        for (my $i = Math::GMPz::Rmpz_init_set_ui(0) ; Math::GMPz::Rmpz_cmp($i, $num) < 0 ; Math::GMPz::Rmpz_add_ui($i, $i, 1))
        {
            $block->run(bless(\Math::GMPz::Rmpz_init_set($i)));
        }

        $_[0];
    }

    sub forperm {
        my ($n, $block) = @_;

        $n = CORE::int(__numify__($$n));

        if (!defined $block) {
            return Sidef::Types::Array::Array->new(map { __PACKAGE__->_set_uint($_) } 0 .. $n - 1)->permutations;
        }

        if ($n == 0) {
            $block->run();
            return $block;
        }

        if ($n < 0) {
            return $block;
        }

        my @idx = (0 .. $n - 1);
        my @nums = map { __PACKAGE__->_set_uint($_) } @idx;

        my @perm;
        while (1) {
            @perm = @nums[@idx];

            my $p = $#idx;
            --$p while $idx[$p - 1] > $idx[$p];

            my $q = $p || do {
                $block->run(@perm);
                return $block;
            };

            CORE::push(@idx, CORE::reverse CORE::splice @idx, $p);
            ++$q while $idx[$p - 1] > $idx[$q];
            @idx[$p - 1, $q] = @idx[$q, $p - 1];

            $block->run(@perm);
        }

        return $block;
    }

    *permutations = \&forperm;

    sub forcomb {
        my ($n, $k, $block) = @_;
        _valid(\$k);

        $n = CORE::int(__numify__($$n));

        if (!defined $block) {
            return Sidef::Types::Array::Array->new(map { __PACKAGE__->_set_uint($_) } 0 .. $n - 1)->combinations($k);
        }

        $k = CORE::int(__numify__($$k));

        if ($k == 0) {
            $block->run();
            return $block;
        }

        ($k < 0 or $k > $n or $n == 0)
          && return $block;

        my @c = (0 .. $k - 1);
        my @nums = map { __PACKAGE__->_set_uint($_) } (0 .. $n - 1);

        while (1) {
            $block->run(@nums[@c]);
            next if ($c[$k - 1]++ < $n - 1);
            my $i = $k - 2;
            $i-- while ($i >= 0 && $c[$i] >= $n - ($k - $i));
            last if $i < 0;
            $c[$i]++;
            while (++$i < $k) { $c[$i] = $c[$i - 1] + 1; }
        }

        return $block;
    }

    *combinations = \&forcomb;

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
        my $f = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_const_pi($f, $ROUND);
        Math::MPFR::Rmpfr_ui_div($f, 180, $f, $ROUND);
        bless \__mul__($f, $$x);
    }

    sub deg2rad {
        my ($x) = @_;
        my $f = Math::MPFR::Rmpfr_init2(CORE::int($PREC));
        Math::MPFR::Rmpfr_const_pi($f, $ROUND);
        Math::MPFR::Rmpfr_div_ui($f, $f, 180, $ROUND);
        bless \__mul__($f, $$x);
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
        *{__PACKAGE__ . '::' . '!!'}  = \&double_factorial;
        *{__PACKAGE__ . '::' . '%%'}  = \&is_div;
        *{__PACKAGE__ . '::' . '>>'}  = \&shift_right;
        *{__PACKAGE__ . '::' . '<<'}  = \&shift_left;
        *{__PACKAGE__ . '::' . '~'}   = \&not;
        *{__PACKAGE__ . '::' . ':'}   = \&pair;
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
