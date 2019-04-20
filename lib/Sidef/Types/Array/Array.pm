package Sidef::Types::Array::Array {

    use utf8;
    use 5.016;

    use List::Util qw();

    use parent qw(
      Sidef::Object::Object
      );

    use overload
      q{""}   => \&_dump,
      q{0+}   => sub { scalar(@{$_[0]}) },
      q{bool} => sub { scalar(@{$_[0]}) };

    use Sidef::Types::Number::Number;
    use Sidef::Types::Block::Block;

    sub new {
        (@_ == 2 && ref($_[1]) eq 'ARRAY')
          ? bless($_[1])
          : do {
            shift(@_);
            bless [@_];
          };
    }

    *call = \&new;

    sub get_value {
        my %addr;

        my $sub = sub {
            my ($obj) = @_;

            my $refaddr = Scalar::Util::refaddr($obj);

            exists($addr{$refaddr})
              && return $addr{$refaddr};

            my @array;
            $addr{$refaddr} = \@array;

            foreach my $item (@$obj) {
                if (index(ref($item), 'Sidef::') == 0) {
                    CORE::push(@array, $item->get_value);
                }
                else {
                    CORE::push(@array, $item);
                }
            }

            $addr{$refaddr};
        };

        local *Sidef::Types::Array::Array::get_value = $sub;
        $sub->($_[0]);
    }

    sub unroll_operator {
        my ($self, $operator, $arg) = @_;

        if (ref($arg) ne ref($self)) {
            $arg = $arg->to_a;
        }

        $operator = "$operator" if ref($operator);

        my @array;

        my @arg  = @$arg;
        my @self = @$self;

        (my $argc = @arg) || return bless(\@self, ref($self));
        my $selfc = @self;

        my $max = $argc > $selfc ? $argc - 1 : $selfc - 1;

        foreach my $i (0 .. $max) {
            CORE::push(@array, $self[$i % $selfc]->$operator($arg[$i % $argc]));
        }

        bless \@array, ref($self);
    }

    *unroll_op = \&unroll_operator;

    sub map_operator {
        my ($self, $operator, @args) = @_;

        $operator = "$operator" if ref($operator);

        my @array;
        foreach my $i (0 .. $#$self) {
            CORE::push(@array, $self->[$i]->$operator(@args));
        }

        bless \@array, ref($self);
    }

    *map_op = \&map_operator;

    sub pam_operator {
        my ($self, $operator, $arg) = @_;

        $operator = "$operator" if ref($operator);

        my @array;
        foreach my $i (0 .. $#$self) {
            CORE::push(@array, $arg->$operator($self->[$i]));
        }

        bless \@array, ref($self);
    }

    *pam_op = \&pam_operator;

    sub reduce_operator {
        my ($self, $operator, $initial) = @_;

        $operator = "$operator" if ref($operator);

        my ($from, $x) = (
                          defined($initial)
                          ? (0, $initial)
                          : (1, $self->[0])
                         );

        foreach my $i ($from .. $#$self) {
            $x = $x->$operator($self->[$i]);
        }
        $x;
    }

    *reduce_op = \&reduce_operator;

    sub cross_operator {
        my ($self, $operator, $arg) = @_;

        if (ref($arg) ne ref($self)) {
            $arg = $arg->to_a;
        }

        $operator = "$operator" if ref($operator);

        my @arg = @$arg;

        my @array;
        if ($operator eq '') {
            foreach my $i (@$self) {
                foreach my $j (@arg) {
                    CORE::push(@array, bless [$i, $j]);
                }
            }
        }
        else {
            foreach my $i (@$self) {
                foreach my $j (@arg) {
                    CORE::push(@array, $i->$operator($j));
                }
            }
        }

        bless \@array, ref($self);
    }

    *cross_op = \&cross_operator;

    sub zip_operator {
        my ($self, $operator, $arg) = @_;

        if (ref($arg) ne ref($self)) {
            $arg = $arg->to_a;
        }

        $operator = "$operator" if ref($operator);

        my @arg  = @$arg;
        my @self = @$self;

        my $self_len = $#self;
        my $arg_len  = $#arg;
        my $min      = $self_len < $arg_len ? $self_len : $arg_len;

        my @array;
        if ($operator eq '') {
            foreach my $i (0 .. $min) {
                CORE::push(@array, bless [$self[$i], $arg[$i]]);
            }
        }
        else {
            foreach my $i (0 .. $min) {
                CORE::push(@array, $self[$i]->$operator($arg[$i]));
            }
        }

        bless \@array, ref($self);
    }

    *zip_op = \&zip_operator;

    sub scalar_operator {
        my ($self, $operator, $scalar) = @_;

        $operator = "$operator" if ref($operator);

        my %addr;    # support for cyclic references

        sub {
            my ($obj) = @_;

            my $refaddr = Scalar::Util::refaddr($obj);

            exists($addr{$refaddr})
              && return $addr{$refaddr};

            my @array;
            $addr{$refaddr} = bless(\@array, ref($obj));

            foreach my $item (@$obj) {
                if (ref($item) eq __PACKAGE__ or UNIVERSAL::isa($item, __PACKAGE__)) {
                    CORE::push(@array, __SUB__->($item));
                }
                else {
                    if ($operator eq '') {
                        CORE::push(@array, bless [$item, $scalar]);
                    }
                    else {
                        CORE::push(@array, $item->$operator($scalar));
                    }
                }
            }

            $addr{$refaddr};
          }
          ->($self);
    }

    *scalar_op = \&scalar_operator;

    sub rscalar_operator {
        my ($self, $operator, $scalar) = @_;

        $operator = "$operator" if ref($operator);

        my %addr;    # support for cyclic references

        sub {
            my ($obj) = @_;

            my $refaddr = Scalar::Util::refaddr($obj);

            exists($addr{$refaddr})
              && return $addr{$refaddr};

            my @array;
            $addr{$refaddr} = bless(\@array, ref($self));

            foreach my $item (@$obj) {
                if (ref($item) eq __PACKAGE__ or UNIVERSAL::isa($item, __PACKAGE__)) {
                    CORE::push(@array, __SUB__->($item));
                }
                else {
                    if ($operator eq '') {
                        CORE::push(@array, bless [$scalar, $item]);
                    }
                    else {
                        CORE::push(@array, $scalar->$operator($item));
                    }
                }
            }

            $addr{$refaddr};
          }
          ->($self);
    }

    *rscalar_op = \&rscalar_operator;

    sub wise_operator {
        my ($m1, $operator, $m2) = @_;

        if (ref($m2) ne ref($m1)) {
            $m2 = $m2->to_a;
        }

        $operator = "$operator" if ref($operator);

        my %addr;    # support for cyclic references

        sub {
            my ($obj1, $obj2) = @_;

            my $refaddr1 = Scalar::Util::refaddr($obj1);
            my $refaddr2 = Scalar::Util::refaddr($obj2);

            exists($addr{$refaddr1})
              && return $addr{$refaddr1};

            exists($addr{$refaddr2})
              && return $addr{$refaddr2};

            my @array;

            $addr{$refaddr2} = $addr{$refaddr1} = bless(\@array, ref($obj1));

            for my $i (0 .. $#{$obj1}) {
                if (ref($obj1->[$i]) eq __PACKAGE__ or UNIVERSAL::isa($obj1->[$i], __PACKAGE__)) {
                    CORE::push(@array, __SUB__->($obj1->[$i], $obj2->[$i]));
                }
                else {
                    if ($operator eq '') {
                        CORE::push(@array, bless [$obj1->[$i], $obj2->[$i]]);
                    }
                    else {
                        CORE::push(@array, $obj1->[$i]->$operator($obj2->[$i]));
                    }
                }
            }

            $addr{$refaddr1};
          }
          ->($m1, $m2);
    }

    *wise_op = \&wise_operator;

    sub combine {
        my ($self, $block) = @_;

        my %addr;    # support for cyclic references

        sub {
            my (@arrays) = @_;

            my @array;
            my $blessed_array = bless \@array, ref($self);

            # Check any references already computed
            foreach my $obj (@arrays) {
                my $refaddr = Scalar::Util::refaddr($obj);
                exists($addr{$refaddr}) && return $addr{$refaddr};
            }

            # Store the references of each object
            foreach my $obj (@arrays) {
                my $refaddr = Scalar::Util::refaddr($obj);
                $addr{$refaddr} = $blessed_array;
            }

            @arrays || return $blessed_array;

            my $first = $arrays[0];

            foreach my $i (0 .. $#{$first}) {
                if (ref($first->[$i]) eq __PACKAGE__ or UNIVERSAL::isa($first->[$i], __PACKAGE__)) {
                    CORE::push(@array, __SUB__->(map { $_->[$i] } @arrays));
                }
                else {
                    CORE::push(@array, $block->run(map { $_->[$i] } @arrays));
                }
            }

            $blessed_array;
          }
          ->(@$self);
    }

    sub mul {
        my ($self, $num) = @_;
        bless [(@$self) x CORE::int($num)];
    }

    sub div {
        my ($self, $num) = @_;

        my @obj = @$self;

        my @array;
        my $len = CORE::int(scalar(@obj) / CORE::int($num));

        my $i   = 1;
        my $pos = $len;
        while (@obj) {
            my $j = $pos - $i * CORE::int($len);
            $pos -= $j if $j >= 1;
            CORE::push(@array, bless [CORE::splice(@obj, 0, $len + $j)]);
            $pos += $len;
            $i++;
        }

        bless \@array;
    }

    sub part {
        my ($self, $num) = @_;

        my @first  = @$self;
        my @second = splice(@first, CORE::int($num));

        (bless(\@first), bless(\@second));
    }

    *partition = \&part;

    sub or {
        my ($self, $array) = @_;

        if (ref($array) eq 'Sidef::Types::Set::Set') {
            return $self->to_set->or($array);
        }

        if (ref($array) eq 'Sidef::Types::Set::Bag') {
            return $self->to_bag->or($array);
        }

        if (ref($array) ne ref($self)) {
            $array = $array->to_a;
        }

        #$self->and($array)->concat($self->xor($array));
        $self->concat($array)->uniq;
    }

    sub xor {
        my ($self, $array) = @_;

        if (ref($array) eq 'Sidef::Types::Set::Set') {
            return $self->to_set->xor($array);
        }

        if (ref($array) eq 'Sidef::Types::Set::Bag') {
            return $self->to_bag->xor($array);
        }

        if (ref($array) ne ref($self)) {
            $array = $array->to_a;
        }

        my @x = CORE::sort { $a cmp $b } @$self;
        my @y = CORE::sort { $a cmp $b } @$array;

        my $endx = $#x;
        my $endy = $#y;

        my $i = 0;
        my $j = 0;

        my ($cmp, @new);

        while (1) {

            $cmp = CORE::int($x[$i] cmp $y[$j]);

            if ($cmp < 0) {
                push @new, $x[$i];
                ++$i;
            }
            elsif ($cmp > 0) {
                push @new, $y[$j];
                ++$j;
            }
            else {
                my $k = $i;
                do { ++$i } while ($i <= $endx and $x[$i] eq $y[$j]);
                do { ++$j } while ($j <= $endy and $x[$k] eq $y[$j]);
            }

            if ($i > $endx) {
                push @new, @y[$j .. $endy];
                last;
            }
            elsif ($j > $endy) {
                push @new, @x[$i .. $endx];
                last;
            }
        }

        bless \@new;
    }

    sub and {
        my ($self, $array) = @_;

        if (ref($array) eq 'Sidef::Types::Set::Set') {
            return $self->to_set->and($array);
        }

        if (ref($array) eq 'Sidef::Types::Set::Bag') {
            return $self->to_bag->and($array);
        }

        if (ref($array) ne ref($self)) {
            $array = $array->to_a;
        }

        my @x = CORE::sort { $a cmp $b } @$self;
        my @y = CORE::sort { $a cmp $b } @$array;

        my $i = 0;
        my $j = 0;

        my $end1 = @x;
        my $end2 = @y;

        my ($cmp, @new);
        while ($i < $end1 and $j < $end2) {

            $cmp = CORE::int($x[$i] cmp $y[$j]);

            if ($cmp < 0) {
                ++$i;
            }
            elsif ($cmp > 0) {
                ++$j;
            }
            else {
                push @new, $x[$i];
                ++$i;
                ++$j;
            }
        }

        bless \@new;
    }

    sub sub {
        my ($self, $array) = @_;

        if (ref($array) eq 'Sidef::Types::Set::Set') {
            return $self->to_set->sub($array);
        }

        if (ref($array) eq 'Sidef::Types::Set::Bag') {
            return $self->to_bag->sub($array);
        }

        if (ref($array) ne ref($self)) {
            $array = $array->to_a;
        }

        my @x = CORE::sort { $a cmp $b } @$self;
        my @y = CORE::sort { $a cmp $b } @$array;

        my $i = 0;
        my $j = 0;

        my $end1 = @x;
        my $end2 = @y;

        my ($cmp, @new);
        while ($i < $end1 and $j < $end2) {

            $cmp = CORE::int($x[$i] cmp $y[$j]);

            if ($cmp < 0) {
                push @new, $x[$i];
                ++$i;
            }
            elsif ($cmp > 0) {
                ++$j;
            }
            else {
                1 while (++$i < $end1 and $x[$i] eq $y[$j]);
            }
        }

        if ($i < $end1) {
            push @new, @x[$i .. $#x];
        }

        bless \@new;
    }

    sub diff {
        my ($self, $array) = @_;

        if (ref($array) eq 'Sidef::Types::Set::Set') {
            return $self->to_set->sub($array);
        }

        if (ref($array) eq 'Sidef::Types::Set::Bag') {
            return $self->to_bag->sub($array);
        }

        if (ref($array) ne ref($self)) {
            $array = $array->to_a;
        }

        my @x = CORE::sort { $a cmp $b } @$self;
        my @y = CORE::sort { $a cmp $b } @$array;

        my $i = 0;
        my $j = 0;

        my $end1 = @x;
        my $end2 = @y;

        my ($cmp, @new);
        while ($i < $end1 and $j < $end2) {

            $cmp = CORE::int($x[$i] cmp $y[$j]);

            if ($cmp < 0) {
                push @new, $x[$i];
                ++$i;
            }
            elsif ($cmp > 0) {
                ++$j;
            }
            else {
                ++$i;
                ++$j;
            }
        }

        if ($i < $end1) {
            push @new, @x[$i .. $#x];
        }

        bless \@new;
    }

    sub concat {
        my ($self, $arg) = @_;

        ref($self) eq ref($arg)
          ? bless([@$self, @$arg])
          : bless([@$self, $arg]);
    }

    *add = \&concat;

    sub levenshtein {
        my ($self, $arg) = @_;

        if (ref($arg) ne ref($self)) {
            $arg = $arg->to_a;
        }

        my @s = @$self;
        my @t = @$arg;

        my $len1 = scalar(@s);
        my $len2 = scalar(@t);

        my @d = ([0 .. $len2], map { [$_] } 1 .. $len1);
        foreach my $i (1 .. $len1) {
            foreach my $j (1 .. $len2) {
                $d[$i][$j] =
                    $s[$i - 1] eq $t[$j - 1]
                  ? $d[$i - 1][$j - 1]
                  : List::Util::min($d[$i - 1][$j], $d[$i][$j - 1], $d[$i - 1][$j - 1]) + 1;
            }
        }

        Sidef::Types::Number::Number->new($d[-1][-1]);
    }

    *lev   = \&levenshtein;
    *leven = \&levenshtein;

    sub jaro_distance {
        my ($self, $arg, $winkler) = @_;

        if (ref($arg) ne ref($self)) {
            $arg = $arg->to_a;
        }

        my @s = @$self;
        my @t = @$arg;

        my $s_len = @s;
        my $t_len = @t;

        if ($s_len == 0 and $t_len == 0) {
            return 1;
        }

        my $match_distance = CORE::int(List::Util::max($s_len, $t_len) / 2) - 1;

        my @s_matches;
        my @t_matches;

        my $matches = 0;
        foreach my $i (0 .. $#s) {

            my $start = List::Util::max(0, $i - $match_distance);
            my $end   = List::Util::min($i + $match_distance + 1, $t_len);

            foreach my $j ($start .. $end - 1) {
                $t_matches[$j] and next;
                $s[$i] eq $t[$j] or next;
                $s_matches[$i] = 1;
                $t_matches[$j] = 1;
                $matches++;
                last;
            }
        }

        return Sidef::Types::Number::Number::ZERO if $matches == 0;

        my $k              = 0;
        my $transpositions = 0;

        foreach my $i (0 .. $#s) {
            $s_matches[$i] or next;
            until ($t_matches[$k]) { ++$k }
            $s[$i] eq $t[$k] or ++$transpositions;
            ++$k;
        }

        my $jaro = (($matches / $s_len) + ($matches / $t_len) + (($matches - $transpositions / 2) / $matches)) / 3;

        $winkler || return Sidef::Types::Number::Number->new($jaro);    # return the Jaro distance instead of Jaro-Winkler

        my $prefix = 0;
        foreach my $i (0 .. List::Util::min(3, $#t, $#s)) {
            $s[$i] eq $t[$i] ? ++$prefix : last;
        }

        Sidef::Types::Number::Number->new($jaro + $prefix * 0.1 * (1 - $jaro));
    }

    sub count_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my $counter = 0;

        foreach my $item (@$self) {
            if ($block->run($item)) {
                ++$counter;
            }
        }

        Sidef::Types::Number::Number->_set_uint($counter);
    }

    sub count {
        my ($self, $obj) = @_;

        if (ref($obj) eq 'Sidef::Types::Block::Block') {
            goto &count_by;
        }

        my $counter = 0;
        foreach my $item (@$self) {
            if ($item eq $obj) {
                ++$counter;
            }
        }

        Sidef::Types::Number::Number->_set_uint($counter);
    }

    sub cmp {
        my ($self, $array) = @_;

        my %addr;    # support for cyclic references

        my $sub = sub {
            my ($a1, $a2) = @_;

            my $l1 = $#$a1;
            my $l2 = $#$a2;

            my $min = $l1 < $l2 ? $l1 : $l2;

            my $refaddr1 = Scalar::Util::refaddr($a1);
            my $refaddr2 = Scalar::Util::refaddr($a2);

            if ($refaddr1 == $refaddr2) {
                return Sidef::Types::Number::Number::ZERO;
            }

            exists($addr{$refaddr1})
              and return $addr{$refaddr1};

            exists($addr{$refaddr2})
              and return $addr{$refaddr2};

            my $cmp1 = $refaddr1 <=> $refaddr2;
            my $cmp2 = $refaddr2 <=> $refaddr1;

            $addr{$refaddr1} = (
                                  $cmp1 == $cmp2 ? Sidef::Types::Number::Number::ZERO
                                : $cmp1 < 0      ? Sidef::Types::Number::Number::MONE
                                :                  Sidef::Types::Number::Number::ONE
                               );

            $addr{$refaddr2} = (
                                  $cmp1 == $cmp2 ? Sidef::Types::Number::Number::ZERO
                                : $cmp2 < 0      ? Sidef::Types::Number::Number::MONE
                                :                  Sidef::Types::Number::Number::ONE
                               );

            foreach my $i (0 .. $min) {
                if (my $cmp = CORE::int($a1->[$i] cmp $a2->[$i])) {
                    return (
                            $cmp < 0
                            ? Sidef::Types::Number::Number::MONE
                            : Sidef::Types::Number::Number::ONE
                           );
                }
            }

                $l1 == $l2 ? Sidef::Types::Number::Number::ZERO
              : $l1 < $l2  ? Sidef::Types::Number::Number::MONE
              :              Sidef::Types::Number::Number::ONE;
        };

        no strict 'refs';
        local *Sidef::Types::Array::Array::cmp = $sub;
        local *{'Sidef::Types::Array::Array::<=>'} = $sub;
        $sub->($self, $array);
    }

    sub lt {
        my ($self, $array) = @_;
        Math::GMPz::Rmpz_sgn(${$self->cmp($array)}) < 0
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub le {
        my ($self, $array) = @_;
        Math::GMPz::Rmpz_sgn(${$self->cmp($array)}) <= 0
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub gt {
        my ($self, $array) = @_;
        Math::GMPz::Rmpz_sgn(${$self->cmp($array)}) > 0
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub ge {
        my ($self, $array) = @_;
        Math::GMPz::Rmpz_sgn(${$self->cmp($array)}) >= 0
          ? Sidef::Types::Bool::Bool::TRUE
          : Sidef::Types::Bool::Bool::FALSE;
    }

    sub eq {
        my ($self, $array) = @_;

        my %addr;    # support for cyclic references

        my $sub = sub {
            my ($a1, $a2) = @_;

            if ($#$a1 != $#$a2) {
                return Sidef::Types::Bool::Bool::FALSE;
            }

            my $refaddr1 = Scalar::Util::refaddr($a1);
            my $refaddr2 = Scalar::Util::refaddr($a2);

            if ($refaddr1 == $refaddr2) {
                return Sidef::Types::Bool::Bool::TRUE;
            }

            exists($addr{$refaddr1})
              and return $addr{$refaddr1};

            exists($addr{$refaddr2})
              and return $addr{$refaddr2};

            $addr{$refaddr1} = Sidef::Types::Bool::Bool::FALSE;
            $addr{$refaddr2} = Sidef::Types::Bool::Bool::FALSE;

            my $i = -1;
            foreach my $item (@$a1) {
                ($item eq $a2->[++$i])
                  or return Sidef::Types::Bool::Bool::FALSE;
            }

            (Sidef::Types::Bool::Bool::TRUE);
        };

        no strict 'refs';
        local *Sidef::Types::Array::Array::eq = $sub;
        local *{'Sidef::Types::Array::Array::=='} = $sub;
        $sub->($self, $array);
    }

    sub ne {
        my ($self, $array) = @_;
        $self->eq($array)->not;
    }

    sub make {
        my ($self, $size, $obj) = @_;
        bless([($obj) x $size]);
    }

    sub make_by {
        my ($self, $size, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @arr;
        foreach my $i (0 .. CORE::int($size) - 1) {
            CORE::push(@arr, $block->run(Sidef::Types::Number::Number->_set_uint($i)));
        }

        bless \@arr;
    }

    sub _min_max {
        my ($self, $order) = @_;

        @$self || return undef;

        my $item = $self->[0];

        foreach my $i (1 .. $#$self) {
            my $value = $self->[$i];
            $item = $value if (CORE::int($value cmp $item) == $order);
        }

        $item;
    }

    sub max {
        @_ = ($_[0], 1);
        goto &_min_max;
    }

    sub min {
        @_ = ($_[0], -1);
        goto &_min_max;
    }

    sub minmax {
        my ($self) = @_;
        ($self->min, $self->max);
    }

    sub collapse {
        my ($self, $initial) = @_;
        $self->reduce_operator('+', $initial);
    }

    sub _sum_prod_by {
        my ($self, $method, $result, $callback) = @_;

        my @list;
        my $count = 0;

        foreach my $k (0 .. $#$self) {
            CORE::push(@list, $callback->($k, $self->[$k]));

            if (++$count > 1e5) {
                $count  = 0;
                $result = $result->$method(CORE::splice(@list));
            }
        }

        if (@list) {
            $result = $result->$method(CORE::splice(@list));
        }

        $result;
    }

    sub sum_by {
        my ($self, $block) = @_;
        $block //= Sidef::Types::Block::Block::IDENTITY;
        $self->_sum_prod_by('sum', Sidef::Types::Number::Number::ZERO, sub { $block->run($_[1]) });
    }

    sub sum_kv {
        my ($self, $block) = @_;
        $self->_sum_prod_by('sum',
                            Sidef::Types::Number::Number::ZERO,
                            sub { $block->run(Sidef::Types::Number::Number->_set_uint($_[0]), $_[1]) });
    }

    sub sum {
        my ($self, $arg) = @_;

        if (defined($arg)) {
            goto &sum_by;
        }

        Sidef::Types::Number::Number::sum(@$self);
    }

    sub avg_by {
        my ($self, $block) = @_;
        $self->sum_by($block)->div($self->len);
    }

    sub avg {
        my ($self, $arg) = @_;

        if (defined($arg)) {
            goto &avg_by;
        }

        $self->sum->div($self->len);
    }

    sub prod_by {
        my ($self, $block) = @_;
        $block //= Sidef::Types::Block::Block::IDENTITY;
        $self->_sum_prod_by('prod', Sidef::Types::Number::Number::ONE, sub { $block->run($_[1]) });
    }

    sub prod_kv {
        my ($self, $block) = @_;
        $self->_sum_prod_by('prod',
                            Sidef::Types::Number::Number::ONE,
                            sub { $block->run(Sidef::Types::Number::Number->_set_uint($_[0]), $_[1]) });
    }

    sub prod {
        my ($self, $arg) = @_;

        if (defined($arg)) {
            goto &prod_by;
        }

        Sidef::Types::Number::Number::prod(@$self);
    }

    sub gcd_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @list;
        foreach my $n (@$self) {
            push @list, $block->run($n);
        }

        Sidef::Types::Number::Number::gcd(@list);
    }

    sub gcd {
        my ($self, $block) = @_;

        if (defined($block)) {
            goto &gcd_by;
        }

        Sidef::Types::Number::Number::gcd(@$self);
    }

    sub lcm_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @list;
        foreach my $n (@$self) {
            push @list, $block->run($n);
        }

        Sidef::Types::Number::Number::lcm(@list);
    }

    sub lcm {
        my ($self, $block) = @_;

        if (defined($block)) {
            goto &lcm_by;
        }

        Sidef::Types::Number::Number::lcm(@$self);
    }

    sub digits2num {
        my ($self, $base) = @_;

        state $ten = Sidef::Types::Number::Number->_set_uint(10);

        $base //= $ten;

        my $sum       = Sidef::Types::Number::Number::ZERO;
        my $base_prod = Sidef::Types::Number::Number::ONE;

        foreach my $v (@$self) {
            $sum       = $sum->add($base_prod->mul($v));
            $base_prod = $base_prod->mul($base);
        }

        $sum;
    }

    sub _min_max_by {
        my ($self, $block, $order) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        @$self || return undef;

        my $minmax  = $self->[0];
        my $old_key = $block->run($minmax);

        foreach my $i (1 .. $#$self) {
            my $value   = $self->[$i];
            my $new_key = $block->run($value);

            if (CORE::int($new_key cmp $old_key) == $order) {
                $minmax  = $value;
                $old_key = $new_key;
            }
        }

        $minmax;
    }

    sub max_by {
        @_ = (@_[0, 1], 1);
        goto &_min_max_by;
    }

    sub min_by {
        @_ = (@_[0, 1], -1);
        goto &_min_max_by;
    }

    sub swap {
        my ($self, $i, $j) = @_;
        @$self[$i, $j] = @$self[$j, $i];
        $self;
    }

    sub change_to {
        my ($self, $arg) = @_;
        @$self = @$arg;
        $self;
    }

    sub _flatten {    # this exists for performance reasons
        my ($self, $class) = @_;

        my @array;
        foreach my $item (@{$self}) {
            CORE::push(@array,
                       (ref($item) eq $class or ref($item) =~ /^Sidef::Types::Array::/)
                       ? _flatten($item, $class)
                       : $item);
        }

        @array;
    }

    sub flatten {
        my ($self) = @_;

        my @flat;
        my $class = ref($self);
        foreach my $item (@{$self}) {
            CORE::push(@flat,
                       (ref($item) eq $class or ref($item) =~ /^Sidef::Types::Array::/)
                       ? _flatten($item, $class)
                       : $item);
        }

        bless \@flat;
    }

    *flat = \&flatten;

    sub exists {
        my ($self, $index) = @_;
        exists($self->[$index])
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    *has_index = \&exists;

    sub defined {
        my ($self, $index) = @_;
        defined($self->[$index])
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub items {
        my ($self, @indices) = @_;
        bless([map { exists($self->[$_]) ? $self->[$_] : undef } @indices]);
    }

    sub item {
        my ($self, $index) = @_;
        exists($self->[$index]) ? $self->[$index] : undef;
    }

    sub fetch {
        my ($self, $index, $default) = @_;
        exists($self->[$index]) ? $self->[$index] : $default;
    }

    sub dig {
        my ($self, $key, @keys) = @_;

        my $value = $self->fetch($key) // return undef;

        foreach my $key (@keys) {
            $value = $value->fetch($key) // return undef;
        }

        $value;
    }

    sub _slice {
        my ($self, $from, $to) = @_;

        my $max = @$self;

        $from = defined($from) ? CORE::int($from) : 0;
        $to   = defined($to)   ? CORE::int($to)   : $max - 1;

        if (abs($from) > $max) {
            return;
        }

        if ($from < 0) {
            $from += $max;
        }

        if ($to < 0) {
            $to += $max;
        }

        if ($to >= $max) {
            $to = $max - 1;
        }

        @$self[$from .. $to];
    }

    sub ft {
        my ($self) = @_;
        bless [_slice(@_)];
    }

    *slice = \&ft;

    sub each {
        my ($self, $block) = @_;

        foreach my $item (@$self) {
            $block->run($item);
        }

        $self;
    }

    *for     = \&each;
    *foreach = \&each;

    sub each_2d {
        my ($self, $block) = @_;

        foreach my $item (@$self) {
            $block->run(@$item);
        }

        $self;
    }

    *each_2D = \&each_2d;

    sub each_slice {
        my ($self, $n, $block) = @_;

        $n = CORE::int($n);

        my $end = @$self;
        for (my $i = $n - 1 ; $i < $end ; $i += $n) {
            $block->run(@$self[$i - ($n - 1) .. $i]);
        }

        my $mod = $end % $n;
        if ($mod != 0) {
            $block->run(@$self[$end - $mod .. $end - 1]);
        }

        $self;
    }

    sub slice_before {
        my ($self, $block) = @_;

        my @new;
        my $i = 0;
        foreach my $item (@$self) {
            if ($block->run($item)) {
                ++$i if @new;
            }
            push @{$new[$i]}, $item;
        }

        bless([map { bless($_) } @new]);
    }

    sub slice_after {
        my ($self, $block) = @_;

        my @new;
        my $i = 0;
        foreach my $item (@$self) {
            CORE::push(@{$new[$i]}, $item);
            ++$i if $block->run($item);
        }

        bless [map { bless($_) } @new];
    }

    sub slices {
        my ($self, $n) = @_;

        $n = CORE::int($n);

        $n <= 0
          && return bless([]);

        my @slices;
        my $end = @$self;
        for (my $i = $n - 1 ; $i < $end ; $i += $n) {
            CORE::push(@slices, bless([@$self[$i - ($n - 1) .. $i]]));
        }

        my $mod = $end % $n;
        if ($mod != 0) {
            CORE::push(@slices, bless([@$self[$end - $mod .. $end - 1]]));
        }

        bless \@slices;
    }

    sub cons {
        my ($self, $n) = @_;

        $n = CORE::int($n);

        my @array;
        foreach my $i ($n - 1 .. $#$self) {
            CORE::push(@array, bless([@$self[$i - $n + 1 .. $i]]));
        }

        bless \@array;
    }

    sub each_cons {
        my ($self, $n, $block) = @_;

        $n = CORE::int($n);

        foreach my $i ($n - 1 .. $#$self) {
            $block->run(@$self[$i - $n + 1 .. $i]);
        }

        $self;
    }

    sub map_cons {
        my ($self, $n, $block) = @_;

        $block //= Sidef::Types::Block::Block::ARRAY_IDENTITY;

        $n = CORE::int($n);

        my @array;
        foreach my $i ($n - 1 .. $#$self) {
            CORE::push(@array, $block->run(@$self[$i - $n + 1 .. $i]));
        }

        bless \@array;
    }

    sub each_index {
        my ($self, $block) = @_;

        foreach my $i (0 .. $#$self) {
            $block->run(Sidef::Types::Number::Number->_set_uint($i));
        }

        $self;
    }

    *each_k   = \&each_index;
    *each_key = \&each_index;

    sub each_kv {
        my ($self, $block) = @_;

        foreach my $i (0 .. $#$self) {
            $block->run(Sidef::Types::Number::Number->_set_uint($i), $self->[$i]);
        }

        $self;
    }

    sub expand {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @new;
        my @copy = @$self;

        foreach my $item (@copy) {
            my $res = $block->run($item);

            if (ref($res) eq __PACKAGE__ or UNIVERSAL::isa($res, __PACKAGE__)) {
                CORE::push(@copy, @$res);
            }
            else {
                CORE::push(@new, $res);
            }
        }

        bless \@new;
    }

    *expand_by = \&expand;

    sub recmap {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @copy = @$self;

        foreach my $item (@copy) {
            my $res = $block->run($item);

            if (ref($res) eq __PACKAGE__ or UNIVERSAL::isa($res, __PACKAGE__)) {
                CORE::push(@copy, @$res);
            }
        }

        bless \@copy;
    }

    sub map {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @array;
        foreach my $item (@$self) {
            CORE::push(@array, $block->run($item));
        }

        bless \@array, ref($self);
    }

    *collect = \&map;

    sub map_2d {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @array;
        foreach my $item (@$self) {
            CORE::push(@array, $block->run(@$item));
        }

        bless \@array, ref($self);
    }

    *map_2D = \&map_2d;

    sub map_kv {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::ARRAY_IDENTITY;

        my @arr;
        foreach my $i (0 .. $#$self) {
            CORE::push(@arr, $block->run(Sidef::Types::Number::Number->_set_uint($i), $self->[$i]));
        }

        bless \@arr, ref($self);
    }

    *collect_kv = \&map_kv;

    sub flat_map {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::ARRAY_IDENTITY;

        my @array;
        foreach my $item (@$self) {
            CORE::push(@array, @{scalar $block->run($item)});
        }

        bless \@array;
    }

    sub grep {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @array;
        foreach my $item (@$self) {
            CORE::push(@array, $item) if $block->run($item);
        }

        bless \@array, ref($self);
    }

    *select = \&grep;

    sub grep_2d {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @array;
        foreach my $item (@$self) {
            CORE::push(@array, $item) if $block->run(@$item);
        }

        bless \@array, ref($self);
    }

    *grep_2D = \&grep_2d;

    sub grep_kv {
        my ($self, $block) = @_;

        my @array;
        foreach my $i (0 .. $#$self) {
            CORE::push(@array, $self->[$i]) if $block->run(Sidef::Types::Number::Number->_set_uint($i), $self->[$i]);
        }

        bless \@array, ref($self);
    }

    *select_kv = \&grep_kv;

    sub group {
        my ($self, $block) = @_;

        my %hash;
        foreach my $item (@$self) {
            CORE::push(@{$hash{$block->run($item)}}, $item);
        }

        Sidef::Types::Hash::Hash->new(map { $_ => bless($hash{$_}) } CORE::keys(%hash));
    }

    *group_by = \&group;

    sub match {
        my ($self, $regex) = @_;

        my %addr;

        my $sub = sub {
            my ($obj) = @_;

            my $refaddr = Scalar::Util::refaddr($obj);

            exists($addr{$refaddr})
              && return Sidef::Types::Bool::Bool::FALSE;

            undef $addr{$refaddr};

            foreach my $item (@$obj) {
                if (defined(my $sub = UNIVERSAL::can($item, 'match'))) {
                    $sub->($item, $regex)
                      && return Sidef::Types::Bool::Bool::TRUE;
                }
                elsif ($regex->run($item)) {
                    return Sidef::Types::Bool::Bool::TRUE;
                }
            }

            Sidef::Types::Bool::Bool::FALSE;
        };

        local *Sidef::Types::Array::Array::match = $sub;
        $sub->($_[0]);
    }

    sub iter {
        my ($self) = @_;

        my $i = 0;
        Sidef::Types::Block::Block->new(
            code => sub {
                $self->[$i++];
            }
        );
    }

    sub freq_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my %hash;
        foreach my $item (@$self) {
            my $r = $hash{$block->run($item)} //= {
                                                   count => 0,
                                                   items => [],
                                                  };
            CORE::push(@{$r->{items}}, $item);
            ++$r->{count};
        }

        my %freq;
        foreach my $key (CORE::keys(%hash)) {
            my $r = $hash{$key};
            my $n = Sidef::Types::Number::Number->_set_uint($r->{count});
            @freq{@{$r->{items}}} = ($n) x scalar(@{$r->{items}});
        }

        Sidef::Types::Hash::Hash->new(%freq);
    }

    sub freq {
        my ($self, $block) = @_;

        if (defined($block)) {
            goto &freq_by;
        }

        my %hash;
        foreach my $item (@$self) {
            $hash{$item}++;
        }

        foreach my $key (CORE::keys %hash) {
            $hash{$key} = Sidef::Types::Number::Number->_set_uint($hash{$key});
        }

        Sidef::Types::Hash::Hash->new(%hash);
    }

    sub first_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        foreach my $val (@$self) {
            return $val if $block->run($val);
        }

        return undef;
    }

    *find = \&first_by;

    sub first {
        my ($self, $arg) = @_;

        if (defined $arg) {

            if (ref($arg) eq 'Sidef::Types::Block::Block') {
                goto &first_by;
            }

            my $end = $#$self;

            $arg = CORE::int($arg) || return bless([], ref($self));
            $arg += $end + 1 if $arg < 0;
            $arg -= 1;

            return bless([@$self[0 .. ($arg > $end ? $end : $arg)]], ref($self));
        }

        @$self ? $self->[0] : undef;
    }

    *head = \&first;

    sub last_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        for (my $i = $#$self ; $i >= 0 ; --$i) {
            return $self->[$i] if $block->run($self->[$i]);
        }

        return undef;
    }

    sub last {
        my ($self, $arg) = @_;

        if (defined $arg) {

            if (ref($arg) eq 'Sidef::Types::Block::Block') {
                goto &last_by;
            }

            my $end = $#$self;

            $arg = CORE::int($arg) || return bless([], ref($self));
            $arg += $end + 1 if $arg < 0;

            my $from = $end - $arg + 1;

            return bless([@$self[($from < 0 ? 0 : $from) .. $end]], ref($self));
        }

        @$self ? $self->[-1] : undef;
    }

    *tail = \&last;

    sub any {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        foreach my $val (@$self) {
            $block->run($val)
              && return (Sidef::Types::Bool::Bool::TRUE);
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    sub all {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        foreach my $val (@$self) {
            $block->run($val)
              || return (Sidef::Types::Bool::Bool::FALSE);
        }

        (Sidef::Types::Bool::Bool::TRUE);
    }

    sub none {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        foreach my $val (@$self) {
            $block->run($val)
              && return (Sidef::Types::Bool::Bool::FALSE);
        }

        (Sidef::Types::Bool::Bool::TRUE);
    }

    sub bindex_by {
        my ($self, $obj) = @_;

        my $left  = 0;
        my $right = $#$self;
        my ($middle, $item, $cmp);

        while ($left <= $right) {

            $middle = (($right + $left) >> 1);
            $item   = $self->[$middle];
            $cmp    = CORE::int($obj->run($item)) || return Sidef::Types::Number::Number->_set_int($middle);

            if ($cmp > 0) {
                $right = $middle - 1;
            }
            else {
                $left = $middle + 1;
            }
        }

        Sidef::Types::Number::Number::MONE;
    }

    *bsearch_index_by = \&bindex_by;

    sub bindex {
        my ($self, $obj) = @_;

        if (ref($obj) eq 'Sidef::Types::Block::Block') {
            goto &bindex_by;
        }

        my $left  = 0;
        my $right = $#$self;
        my ($middle, $item, $cmp);

        while ($left <= $right) {
            $middle = (($right + $left) >> 1);
            $item   = $self->[$middle];
            $cmp    = CORE::int($item cmp $obj) || return Sidef::Types::Number::Number->_set_int($middle);

            if ($cmp > 0) {
                $right = $middle - 1;
            }
            else {
                $left = $middle + 1;
            }
        }

        Sidef::Types::Number::Number::MONE;
    }

    *bsearch_index = \&bindex;

    sub bsearch {
        my ($self, $obj) = @_;
        my $index = $self->bindex($obj);
        $index->is_mone ? undef : $self->[CORE::int($index)];
    }

    *bsearch_by = \&bsearch;

    sub bindex_ge_by {
        my ($self, $obj) = @_;

        my $left  = 0;
        my $right = $#$self;
        my ($middle, $item, $cmp);

        while (1) {

            $middle = (($right + $left) >> 1);
            $item   = $self->[$middle];
            $cmp    = CORE::int($obj->run($item)) || return Sidef::Types::Number::Number->_set_int($middle);

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

        Sidef::Types::Number::Number->_set_int($middle);
    }

    sub bindex_ge {
        my ($self, $obj) = @_;

        if (ref($obj) eq 'Sidef::Types::Block::Block') {
            goto &bindex_ge_by;
        }

        my $left  = 0;
        my $right = $#$self;
        my ($middle, $item, $cmp);

        while (1) {

            $middle = (($right + $left) >> 1);
            $item   = $self->[$middle];
            $cmp    = CORE::int($item cmp $obj) || return Sidef::Types::Number::Number->_set_int($middle);

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

        Sidef::Types::Number::Number->_set_int($middle);
    }

    sub bindex_le_by {
        my ($self, $obj) = @_;

        my $left  = 0;
        my $right = $#$self;
        my ($middle, $item, $cmp);

        while (1) {

            $middle = (($right + $left) >> 1);
            $item   = $self->[$middle];
            $cmp    = CORE::int($obj->run($item)) || return Sidef::Types::Number::Number->_set_int($middle);

            if ($cmp < 0) {
                $left = $middle + 1;
                $left > $right && last;
            }
            else {
                $right = $middle - 1;
                if ($left > $right) {
                    --$middle;
                    last;
                }
            }
        }

        Sidef::Types::Number::Number->_set_int($middle);
    }

    sub bindex_le {
        my ($self, $obj) = @_;

        if (ref($obj) eq 'Sidef::Types::Block::Block') {
            goto &bindex_le_by;
        }

        my $left  = 0;
        my $right = $#$self;
        my ($middle, $item, $cmp);

        while (1) {

            $middle = (($right + $left) >> 1);
            $item   = $self->[$middle];
            $cmp    = CORE::int($item cmp $obj) || return Sidef::Types::Number::Number->_set_int($middle);

            if ($cmp < 0) {
                $left = $middle + 1;
                $left > $right && last;
            }
            else {
                $right = $middle - 1;
                if ($left > $right) {
                    --$middle;
                    last;
                }
            }
        }

        Sidef::Types::Number::Number->_set_int($middle);
    }

    sub bsearch_le {
        my ($self, $obj) = @_;
        my $index = $self->bindex_le($obj);
        $index->is_mone ? undef : $self->[CORE::int($index)];
    }

    *bsearch_le_by = \&bsearch_le;

    sub bsearch_ge {
        my ($self, $obj) = @_;
        my $index = $self->bindex_ge($obj);
        $index->is_mone ? undef : $self->[CORE::int($index)];
    }

    *bsearch_ge_by = \&bsearch_ge;

    sub index {
        my ($self, $obj) = @_;

        if (@_ > 1) {

            if (ref($obj) eq 'Sidef::Types::Block::Block') {
                foreach my $i (0 .. $#$self) {
                    $obj->run($self->[$i])
                      && return Sidef::Types::Number::Number->_set_uint($i);
                }
                return Sidef::Types::Number::Number::MONE;
            }

            foreach my $i (0 .. $#$self) {
                $self->[$i] eq $obj
                  and return Sidef::Types::Number::Number->_set_uint($i);
            }

            return Sidef::Types::Number::Number::MONE;
        }

        @$self
          ? Sidef::Types::Number::Number::ZERO
          : Sidef::Types::Number::Number::MONE;
    }

    *index_by       = \&index;
    *first_index    = \&index;
    *first_index_by = \&index;

    sub rindex {
        my ($self, $obj) = @_;

        if (@_ > 1) {
            if (ref($obj) eq 'Sidef::Types::Block::Block') {
                for (my $i = $#$self ; $i >= 0 ; $i--) {
                    $obj->run($self->[$i])
                      && return Sidef::Types::Number::Number->_set_uint($i);
                }

                return Sidef::Types::Number::Number::MONE;
            }

            for (my $i = $#$self ; $i >= 0 ; $i--) {
                $self->[$i] eq $obj
                  and return Sidef::Types::Number::Number->_set_uint($i);
            }

            return Sidef::Types::Number::Number::MONE;
        }

        $self->end;
    }

    *rindex_by     = \&rindex;
    *last_index    = \&rindex;
    *last_index_by = \&rindex;

    sub pairmap {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::ARRAY_IDENTITY;

        my $end = @$self;

        my @array;
        for (my $i = 1 ; $i < $end ; $i += 2) {
            CORE::push(@array, $block->run(@$self[$i - 1, $i]));
        }

        bless \@array;
    }

    *pair_map = \&pairmap;

    sub shuffle {
        my ($self) = @_;
        bless [List::Util::shuffle(@$self)], ref($self);
    }

    sub weighted_shuffle_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

#<<<
        my @weights = map {
            Sidef::Types::Number::Number::__numify__(${Sidef::Types::Number::Number->new(scalar $block->run($_))})
        } @$self;
#>>>

        my @vals  = @$self;
        my $total = List::Util::sum(@weights);

        my @shuffled;
        while (@vals > 1) {
            my $select = CORE::int(CORE::rand($total));

            my $idx = 0;
            while ($select >= $weights[$idx]) {
                $select -= $weights[$idx++];
            }

            CORE::push(@shuffled, CORE::splice(@vals, $idx, 1));
            $total -= CORE::splice(@weights, $idx, 1);
        }

        CORE::push(@shuffled, @vals) if @vals;
        bless \@shuffled, ref($self);
    }

    sub best_shuffle {
        my ($s) = @_;
        my ($t) = $s->shuffle;

        my $end = $#$s;

        foreach my $i (0 .. $end) {
            foreach my $j (0 .. $end) {
                $i != $j
                  && !($t->[$i] eq $s->[$j])
                  && !($t->[$j] eq $s->[$i])
                  && do {
                    @$t[$i, $j] = @$t[$j, $i];
                    last;
                }
            }
        }

        $t;
    }

    *bshuffle = \&best_shuffle;

    sub accumulate_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @acc;
        my $prev;

        foreach my $item (@$self) {
            if (defined($prev)) {
                CORE::push(@acc, $prev = $prev->add($block->run($item)));
            }
            else {
                CORE::push(@acc, $prev = $block->run($item));
            }
        }

        bless \@acc, ref($self);
    }

    sub accumulate {
        my ($self, $block) = @_;

        if (defined($block)) {
            goto &accumulate_by;
        }

        my @acc;
        my $prev;

        foreach my $item (@$self) {
            if (defined($prev)) {
                CORE::push(@acc, $prev = $prev->add($item));
            }
            else {
                CORE::push(@acc, $prev = $item);
            }
        }

        bless \@acc, ref($self);
    }

    sub reduce {
        my ($self, $obj, $initial) = @_;

        if (ref($obj) eq 'Sidef::Types::Block::Block') {

            my ($from, $x) = (
                              defined($initial)
                              ? (0, $initial)
                              : (1, $self->[0])
                             );

            foreach my $i ($from .. $#$self) {
                $x = $obj->run($x, $self->[$i]);
            }

            return $x;
        }

        $self->reduce_operator("$obj", $initial);
    }

    *inject = \&reduce;

    sub map_reduce {
        my ($self, $obj, $initial) = @_;

        my ($from, $x) = (
                          defined($initial)
                          ? (0, $initial)
                          : (1, $self->[0])
                         );

        my @list = ($x);
        foreach my $i ($from .. $#$self) {
            $x = $obj->run($x, $self->[$i]);
            CORE::push(@list, $x);
        }

        bless \@list, ref($self);
    }

    sub length {
        my ($self) = @_;
        Sidef::Types::Number::Number->_set_uint(scalar @$self);
    }

    *len  = \&length;    # alias
    *size = \&length;

    sub end {
        my $end = $#{$_[0]};
        $end >= 0
          ? Sidef::Types::Number::Number->_set_uint($end)
          : Sidef::Types::Number::Number->_set_int($end);
    }

    *offset = \&end;

    sub resize {
        my ($self, $num) = @_;
        $#$self = $num;
        $self;
    }

    *resize_to = \&resize;

    sub pick {
        my ($self, $amount) = @_;

        if (defined $amount) {
            $amount = CORE::int($amount);

            my $len = @$self;
            if ($amount >= $len) {
                return bless([List::Util::shuffle(@$self)], ref($self));
            }

            my @result;
            for (my ($i, $amount_left) = (0, $len) ; $amount > 0 ; ++$i, --$amount_left) {
                my $rand = CORE::int(CORE::rand($amount_left));
                if ($rand < $amount) {
                    CORE::push(@result, $self->[$i]);
                    $amount--;
                }
            }

            return bless([List::Util::shuffle(@result)], ref($self));
        }

        $self->[CORE::rand(scalar @$self)];
    }

    sub rand {
        my ($self, $amount) = @_;

        if (defined $amount) {
            $amount = CORE::int($amount);

            my $len = @$self;
            return (
                    $len > 0
                    ? bless([map { $self->[CORE::rand($len)] } 1 .. $amount], ref($self))
                    : bless([], ref($self))
                   );
        }

        $self->[CORE::rand(scalar @$self)];
    }

    *sample = \&rand;

    sub range {
        my ($self) = @_;
        Sidef::Types::Range::RangeNumber->new(Sidef::Types::Number::Number::ZERO,
                                              Sidef::Types::Number::Number->_set_int($#$self),
                                              Sidef::Types::Number::Number::ONE,
                                             );
    }

    sub indices_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @indices;
        foreach my $i (0 .. $#$self) {
            if ($block->run($self->[$i])) {
                CORE::push(@indices, Sidef::Types::Number::Number->_set_uint($i));
            }
        }

        bless \@indices;
    }

    *keys_by = \&indices_by;

    sub indices_of {
        my ($self, $arg) = @_;

        my @indices;
        foreach my $i (0 .. $#$self) {
            if ($self->[$i] eq $arg) {
                CORE::push(@indices, Sidef::Types::Number::Number->_set_uint($i));
            }
        }

        bless \@indices;
    }

    *keys_of = \&indices_of;

    sub indices {
        my ($self, $arg) = @_;

        if (defined($arg)) {
            goto &indices_by;
        }

        bless [map { Sidef::Types::Number::Number->_set_uint($_) } 0 .. $#$self];
    }

    *keys = \&indices;

    sub pairs {
        my ($self) = @_;
        bless [map { Sidef::Types::Array::Pair->new(Sidef::Types::Number::Number->_set_uint($_), $self->[$_]) } 0 .. $#$self];
    }

    *kv          = \&pairs;
    *zip_indices = \&pairs;

    sub insert {
        my ($self, $i, @objects) = @_;

        $i = CORE::int($i);

        if ($#$self < $i) {
            $#$self = $i - 1;
        }

        CORE::splice(@$self, $i, 0, @objects);
        $self;
    }

    sub binsert {
        my ($self, $obj) = @_;

        my $left  = 0;
        my $right = $#$self;
        my ($middle, $item, $cmp);

        if ($right < 0) {
            CORE::push(@$self, $obj);
            return $self;
        }

        while (1) {
            $middle = (($right + $left) >> 1);
            $item   = $self->[$middle];
            $cmp    = CORE::int($item cmp $obj) || last;

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

        CORE::splice(@$self, $middle, 0, $obj);
        $self;
    }

    sub compact {
        my ($self) = @_;
        bless [grep { defined($_) } @$self], ref($self);
    }

    sub unique {
        my ($self) = @_;

        my @sorted = do {
            my @arr;
            foreach my $i (0 .. $#$self) {
                CORE::push(@arr, [$i, $self->[$i]]);
            }
            CORE::sort { $a->[1] cmp $b->[1] } @arr;
        };

        my @unique;
        my $max = $#sorted;

        for (my $i = 0 ; $i <= $max ; $i++) {
            $unique[$sorted[$i][0]] = $sorted[$i][1];
            ++$i while ($i < $max and $sorted[$i][1] eq $sorted[$i + 1][1]);
        }

        bless [grep { defined($_) } @unique], ref($self);
    }

    *uniq     = \&unique;
    *distinct = \&unique;

    sub last_unique {
        my ($self) = @_;

        my @sorted = do {
            my @arr;
            foreach my $i (0 .. $#$self) {
                CORE::push(@arr, [$i, $self->[$i]]);
            }
            CORE::sort { $a->[1] cmp $b->[1] } @arr;
        };

        my @unique;
        my $max = $#sorted;

        for (my $i = 0 ; $i <= $max ; $i++) {
            ++$i while ($i < $max and $sorted[$i][1] eq $sorted[$i + 1][1]);
            $unique[$sorted[$i][0]] = $sorted[$i][1];
        }

        bless [grep { defined($_) } @unique], ref($self);
    }

    *last_uniq = \&last_unique;

    sub uniq_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @sorted = do {
            my @arr;
            my $i = -1;
            foreach my $item (@$self) {
                CORE::push(@arr, [++$i, $item, scalar $block->run($item)]);
            }
            CORE::sort { $a->[2] cmp $b->[2] } @arr;
        };

        my @unique;
        my $max = $#sorted;

        for (my $i = 0 ; $i <= $max ; $i++) {
            $unique[$sorted[$i][0]] = $sorted[$i][1];
            ++$i while ($i < $max and $sorted[$i][2] eq $sorted[$i + 1][2]);
        }

        bless [grep { defined } @unique], ref($self);
    }

    *unique_by = \&uniq_by;

    sub last_uniq_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @sorted = do {
            my @arr;
            my $i = -1;
            foreach my $item (@$self) {
                CORE::push(@arr, [++$i, $item, scalar $block->run($item)]);
            }
            CORE::sort { $a->[2] cmp $b->[2] } @arr;
        };

        my @unique;
        my $max = $#sorted;

        for (my $i = 0 ; $i <= $max ; $i++) {
            ++$i while ($i < $max and $sorted[$i][2] eq $sorted[$i + 1][2]);
            $unique[$sorted[$i][0]] = $sorted[$i][1];
        }

        bless [grep { defined } @unique], ref($self);
    }

    *last_unique_by = \&last_uniq_by;

    sub abbrev {
        my ($self, $pattern) = @_;

        if (defined($pattern)) {
            if (ref($pattern) eq 'Sidef::Types::Regex::Regex') {
                $pattern = $pattern->get_value;
            }
            else {
                $pattern = qr/\Q$pattern\E/;
            }
        }

        my (%seen, %table);
        foreach my $item (@$self) {
            my $word   = "$item";
            my $length = CORE::length($word) || next;

            for (my $len = $length ; $len >= 1 ; --$len) {
                my $abbrev = substr($word, 0, $len);

                if (defined($pattern)) {
                    ($abbrev =~ $pattern) || next;
                }

                my $count = ++$seen{$abbrev};

                if ($count == 1) {
                    $table{$abbrev} = $item;
                }
                elsif ($count == 2) {
                    CORE::delete($table{$abbrev});
                }
                else {
                    last;
                }
            }
        }

        foreach my $item (@$self) {
            my $word = "$item";

            if (defined($pattern)) {
                ($word =~ $pattern) || next;
            }

            $table{$word} = $item;
        }

        Sidef::Types::Hash::Hash->new(%table);
    }

    *abbreviations = \&abbrev;

    sub uniq_prefs {
        my ($self, $block) = @_;

        my $tail     = {};                # some unique value
        my $callback = defined($block);

        my %table;
        foreach my $sub_array (@$self) {
            my $ref = \%table;
            foreach my $item (@$sub_array) {
                $ref = $ref->{$item} //= {};
            }
            $ref->{$tail} = $sub_array;
        }

        my @abbrev;
        sub {
            my ($hash) = @_;

            foreach my $key (my @keys = CORE::sort(keys(%{$hash}))) {
                next if $key eq $tail;
                __SUB__->($hash->{$key});

                if ($#keys > 0) {
                    my $count = 0;
                    my $ref   = delete $hash->{$key};
                    while (my ($key) = CORE::each %{$ref}) {
                        if ($key eq $tail) {

                            if ($callback) {
                                $block->run(@{$ref->{$key}}[0 .. $#{$ref->{$key}} - $count]);
                            }
                            else {
                                CORE::push(@abbrev, bless([@{$ref->{$key}}[0 .. $#{$ref->{$key}} - $count]]));
                            }

                            last;
                        }
                        $ref = $ref->{$key};
                        $count++;
                    }
                }
            }
          }
          ->(\%table);

        bless \@abbrev;
    }

    *unique_prefixes = \&uniq_prefs;

    sub contains {
        my ($self, $obj) = @_;

        if (ref($obj) eq 'Sidef::Types::Block::Block') {
            foreach my $item (@$self) {
                if ($obj->run($item)) {
                    return (Sidef::Types::Bool::Bool::TRUE);
                }
            }

            return (Sidef::Types::Bool::Bool::FALSE);
        }

        foreach my $item (@$self) {
            if ($item eq $obj) {
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    *contain  = \&contains;
    *include  = \&contains;
    *includes = \&contains;

    sub contains_type {
        my ($self, $obj) = @_;

        my $ref = ref($obj);

        foreach my $item (@$self) {
            if (ref($item) eq $ref || UNIVERSAL::isa($item, $ref)) {
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        return (Sidef::Types::Bool::Bool::FALSE);
    }

    sub contains_any {
        my ($self, $array) = @_;

        if (ref($array) ne __PACKAGE__) {
            $array = $array->to_a;
        }

        foreach my $item (@$array) {
            if ($self->contains($item)) {
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    sub contains_all {
        my ($self, $array) = @_;

        if (ref($array) ne __PACKAGE__) {
            $array = $array->to_a;
        }

        foreach my $item (@$array) {
            unless ($self->contains($item)) {
                return (Sidef::Types::Bool::Bool::FALSE);
            }
        }

        (Sidef::Types::Bool::Bool::TRUE);
    }

    sub shift {
        my ($self, $num) = @_;

        if (defined $num) {
            return bless([CORE::splice(@$self, 0, $num)], ref($self));
        }

        shift(@$self);
    }

    *drop_first = \&shift;
    *drop_left  = \&shift;

    sub shift_while {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        while (@$self and $block->run($self->[0])) {
            CORE::shift(@$self);
        }

        $self;
    }

    sub pop {
        my ($self, $num) = @_;

        if (defined $num) {
            $num = CORE::int($num);
            $num = $num > $#$self ? 0 : @$self - $num;
            return bless([CORE::splice(@$self, $num)], ref($self));
        }

        pop(@$self);
    }

    *drop_last  = \&pop;
    *drop_right = \&pop;

    sub pop_while {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        while (@$self and $block->run($self->[-1])) {
            CORE::pop(@$self);
        }

        $self;
    }

    sub pop_rand {
        my ($self) = @_;
        $#$self > -1 || return undef;
        CORE::splice(@$self, CORE::rand(scalar @$self), 1);
    }

    sub delete_index {
        my ($self, $offset) = @_;
        CORE::splice(@$self, $offset, 1);
    }

    *pop_at    = \&delete_index;
    *delete_at = \&delete_index;

    sub splice {
        my ($self, $offset, $length, @objects) = @_;

        $offset = defined($offset) ? CORE::int($offset) : 0;
        $length = defined($length) ? CORE::int($length) : scalar(@$self);

        bless [CORE::splice(@$self, $offset, $length, @objects)], ref($self);
    }

    sub take_right {
        my ($self, $amount) = @_;

        my $end = $#$self;
        $amount = CORE::int($amount);
        $amount = $end > ($amount - 1) ? $amount - 1 : $end;

        bless [@$self[$end - $amount .. $end]], ref($self);
    }

    sub take_left {
        my ($self, $amount) = @_;

        my $end = $#$self;
        $amount = CORE::int($amount);
        $amount = $end > ($amount - 1) ? $amount - 1 : $end;

        bless [@$self[0 .. $amount]], ref($self);
    }

    sub is_empty {
        my ($self) = @_;
        ($#$self < 0)
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub clear {
        my ($self) = @_;
        @$self = ();
        $self;
    }

    sub sort {
        my ($self, $block) = @_;

        if (defined $block) {
            return bless [CORE::sort { scalar $block->run($a, $b) } @$self], ref($self);
        }

        bless [CORE::sort { $a cmp $b } @$self], ref($self);
    }

    sub sort_by {
        my ($self, $block) = @_;
        $block //= Sidef::Types::Block::Block::IDENTITY;
        my @keys = map { scalar $block->run($_) } @$self;
        bless [@{$self}[CORE::sort { $keys[$a] cmp $keys[$b] } 0 .. $#$self]], ref($self);
    }

    foreach my $name (
                      qw(
                      derangements
                      permutations
                      circular_permutations
                      )
      ) {

        no strict 'refs';

        *{__PACKAGE__ . '::' . $name} = sub {
            my ($self, $block) = @_;

            require Algorithm::Combinatorics;
            my $iter = &{'Algorithm::Combinatorics::' . $name}([@$self]);

            if (defined($block)) {
                while (defined(my $arr = $iter->next)) {
                    $block->run(@$arr);
                }
                return $self;
            }

            my @result;
            while (defined(my $arr = $iter->next)) {
                push @result, bless [@$arr];
            }

            bless \@result;
        };
    }

    *complete_permutations = \&derangements;

    foreach my $name (
                      qw(
                      variations
                      variations_with_repetition
                      combinations
                      combinations_with_repetition
                      subsets
                      )
      ) {

        no strict 'refs';

        *{__PACKAGE__ . '::' . $name} = sub {
            my ($self, $k, $block) = @_;

            require Algorithm::Combinatorics;

            if (not defined($block) and ref($k) eq 'Sidef::Types::Block::Block') {
                ($block, $k) = ($k, undef);
            }

            my $iter = do {
                local $SIG{__WARN__} = sub { };
                &{'Algorithm::Combinatorics::' . $name}([@$self], defined($k) ? CORE::int($k) : ());
            };

            if (defined($block)) {
                while (defined(my $arr = $iter->next)) {
                    $block->run(@$arr);
                }
                return $self;
            }

            my @result;
            while (defined(my $arr = $iter->next)) {
                push @result, bless [@$arr];
            }

            bless \@result;
        };
    }

    *tuples                 = \&variations;
    *tuples_with_repetition = \&variations_with_repetition;

    sub partitions {
        my ($self, $k, $block) = @_;

        require Algorithm::Combinatorics;

        if (not defined($block) and ref($k) eq 'Sidef::Types::Block::Block') {
            ($block, $k) = ($k, undef);
        }

        my $iter = do {
            local $SIG{__WARN__} = sub { };
            Algorithm::Combinatorics::partitions([@$self], defined($k) ? CORE::int($k) : ());
        };

        if (defined($block)) {
            while (defined(my $arr = $iter->next)) {
                $block->run(map { bless $_ } @$arr);
            }
            return $self;
        }

        my @result;
        while (defined(my $arr = $iter->next)) {
            push @result, bless [map { bless $_ } @$arr];
        }

        bless \@result;
    }

    sub nth_permutation {
        my ($self, $n) = @_;

        my @perm;
        my @arr = @$self;

        $n = Sidef::Types::Number::Number->new($n)->int;
        $n = ref($$n) eq 'Math::GMPz' ? Math::GMPz::Rmpz_init_set($$n) : return undef;

        my $sgn = Math::GMPz::Rmpz_sgn($n);

        if ($sgn < 0) {
            Math::GMPz::Rmpz_neg($n, $n);
            @arr = CORE::reverse(@arr);
        }
        elsif ($sgn == 0) {
            return bless \@arr;
        }

        state $f = Math::GMPz::Rmpz_init_nobless();
        state $q = Math::GMPz::Rmpz_init_nobless();

        Math::GMPz::Rmpz_fac_ui($f, scalar(@arr));    # f = factorial(len)

        while (my $len = scalar(@arr)) {
            Math::GMPz::Rmpz_divexact_ui($f, $f, $len);    # f = f/len
            Math::GMPz::Rmpz_divmod($q, $n, $n, $f);       # q = n//f ;; n = n%f
            Math::GMPz::Rmpz_mod_ui($q, $q, $len);         # q = q%len
            CORE::push(@perm, CORE::splice(@arr, Math::GMPz::Rmpz_get_ui($q), 1));
        }

        bless \@perm;
    }

    *nth_perm = \&nth_permutation;

    sub perm2num {
        my ($self) = @_;
        Sidef::Types::Number::Number->_set_str('int',
                                            Math::Prime::Util::GMP::permtonum([map { CORE::int($_) } @$self]) // return undef);
    }

    sub det_bareiss {
        my ($self) = @_;
        $self->to_matrix->det_bareiss;
    }

    # Reduced row echelon form
    sub rref {
        my ($self) = @_;
        $self->to_matrix->rref;
    }

    *reduced_row_echelon_form = \&rref;

    sub gauss_jordan_invert {
        my ($self) = @_;
        $self->to_matrix->gauss_jordan_invert;
    }

    sub gauss_jordan_solve {
        my ($self, $vector) = @_;
        $self->to_matrix->gauss_jordan_solve($vector);
    }

    sub matrix_solve {
        my ($self, $vector) = @_;
        $self->to_matrix->solve($vector);
    }

    *msolve = \&matrix_solve;

    sub invert {
        my ($self) = @_;
        $self->to_matrix->invert;
    }

    *inv     = \&invert;
    *inverse = \&invert;

    sub determinant {
        my ($self) = @_;
        $self->to_matrix->det;
    }

    *det = \&determinant;

    sub matrix_add {
        my ($m1, $m2) = @_;
        $m1->wise_operator('+', $m2);
    }

    *madd = \&matrix_add;

    sub matrix_sub {
        my ($m1, $m2) = @_;
        $m1->wise_operator('-', $m2);
    }

    *msub = \&matrix_sub;

    sub matrix_mul {
        my ($m1, $m2) = @_;
        $m1->to_matrix->mul($m2);
    }

    *mmul = \&matrix_mul;

    sub matrix_div {
        my ($m1, $m2) = @_;
        $m1->matrix_mul($m2->to_matrix->inv);
    }

    *mdiv = \&matrix_div;

    sub scalar_add {
        my ($self, $scalar) = @_;
        $self->scalar_operator('+', $scalar);
    }

    *sadd = \&scalar_add;

    sub scalar_sub {
        my ($self, $scalar) = @_;
        $self->scalar_operator('-', $scalar);
    }

    *ssub = \&scalar_sub;

    sub scalar_mul {
        my ($self, $scalar) = @_;
        $self->scalar_operator('*', $scalar);
    }

    *smul = \&scalar_mul;

    sub scalar_div {
        my ($self, $scalar) = @_;
        $self->scalar_operator('/', $scalar);
    }

    *sdiv = \&scalar_div;

    sub matrix_pow {
        my ($A, $pow) = @_;
        $A->to_matrix->pow($pow);
    }

    *mpow = \&matrix_pow;

    sub _pipeline_op_call {
        my ($obj, $callback) = @_;

        my @args;

        if (ref($callback) eq __PACKAGE__) {
            @args     = @$callback;
            $callback = CORE::shift(@args);
        }

        if (ref($callback) eq 'Sidef::Types::Block::Block') {
            return $callback->call($obj, @args);
        }
        elsif (ref($callback) eq 'Sidef::Types::String::String') {
            return $obj->$$callback(@args);
        }

        die "[ERROR] Invalid callback object: expected Block or String, but got <<", ref($callback), ">>";
    }

    sub pipeline_cross_op {
        my ($self, @callbacks) = @_;

        my @list;
        foreach my $item (@$self) {
            foreach my $callback (@callbacks) {
                push @list, _pipeline_op_call($item, $callback);
            }
        }

        bless \@list, ref($self);
    }

    sub pipeline_map_op {
        my ($self, $callback, @args) = @_;

        if (@args) {
            $callback = bless [$callback, @args];
        }

        my @list;

        foreach my $item (@$self) {
            push @list, _pipeline_op_call($item, $callback);
        }

        bless \@list, ref($self);
    }

    sub pipeline_zip_op {
        my ($self, @callbacks) = @_;

        my $argc = scalar(@callbacks);
        my @copy = @$self;

        my @list;

        while (1) {

            (my @tmp = CORE::splice(@copy, 0, $argc)) == $argc or last;

            for my $i (0 .. $argc - 1) {
                push @list, _pipeline_op_call($tmp[$i], $callbacks[$i]);
            }
        }

        bless \@list, ref($self);
    }

    sub cartesian {
        my ($self, $block) = @_;

        require Algorithm::Loops;

        my $iter = Algorithm::Loops::NestedLoops([map { [@$_] } @$self]);

        if (defined($block)) {
            while (my @arr = $iter->()) {
                $block->run(@arr);
            }
            return $self;
        }

        my @result;
        while (my @arr = $iter->()) {
            push @result, bless \@arr;
        }
        bless \@result;
    }

    sub zip {
        my ($self, $block) = @_;

        my @arrays = @$self;
        my $min    = List::Util::min(map { scalar @$_ } @arrays);

        my @new_array;
        foreach my $i (0 .. $min - 1) {

            my @tmp = (map { $_->[$i] } @arrays);

            if (defined($block)) {
                $block->run(@tmp);
            }
            else {
                CORE::push(@new_array, bless \@tmp);
            }
        }

        defined($block) ? $self : bless \@new_array;
    }

    *transpose = \&zip;

    sub zip_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::ARRAY_IDENTITY;

        my @arrays = @$self;
        my $min    = List::Util::min(map { scalar @$_ } @arrays);

        my @new_array;
        foreach my $i (0 .. $min - 1) {
            CORE::push(@new_array, $block->run(map { $_->[$i] } @arrays));
        }

        bless \@new_array;
    }

    sub unzip_by {
        my ($self, $block) = @_;

        my @matrix;
        foreach my $i (0 .. $#$self) {

            my @tmp = $block->run($self->[$i]);

            if (@tmp < @matrix) {
                $#tmp = $#matrix;
            }

            foreach my $j (0 .. $#tmp) {
                $matrix[$j][$i] = $tmp[$j];
            }
        }

        bless $_ for @matrix;
        bless \@matrix;
    }

    sub pack {
        my ($self, $format) = @_;
        Sidef::Types::String::String->new(CORE::pack("$format", @$self));
    }

    sub push {
        my ($self, @args) = @_;
        CORE::push(@$self, @args);
        $self;
    }

    *append = \&push;

    sub unshift {
        my ($self, @args) = @_;
        CORE::unshift(@$self, @args);
        $self;
    }

    *prepend = \&unshift;

    sub rotate {
        my ($self, $num) = @_;

        my $len = $#$self + 1;
        return bless([]) if $len == 0;
        $num = CORE::int($num) % $len;
        return bless([@$self], ref($self)) if $num == 0;

        my @array = @$self;
        CORE::unshift(@array, CORE::splice(@array, $num));
        bless \@array, ref($self);
    }

    sub join {
        my ($self, $delim, $block) = @_;
        $delim = defined($delim) ? "$delim" : '';

        if (defined $block) {
            return Sidef::Types::String::String->new(CORE::join($delim, map { scalar $block->run($_) } @$self));
        }

        Sidef::Types::String::String->new(CORE::join($delim, @$self));
    }

    sub join_bytes {
        my ($self, $encoding) = @_;
        state $x = require Encode;
        $encoding = defined($encoding) ? "$encoding" : 'UTF-8';
        Sidef::Types::String::String->new(
            eval {
                Encode::decode($encoding, CORE::join('', map { CORE::chr($_) } @$self));
              } // return
        );
    }

    *chrs   = \&join_bytes;
    *decode = \&join_bytes;

    sub reverse {
        my ($self) = @_;
        bless [CORE::reverse @$self], ref($self);
    }

    *flip = \&reverse;

    sub delete_first {
        my ($self, $obj) = @_;

        foreach my $i (0 .. $#$self) {
            if ($self->[$i] eq $obj) {
                CORE::splice(@$self, $i, 1);
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    *remove_first = \&delete_first;

    sub delete_last {
        my ($self, $obj) = @_;

        for (my $i = $#$self ; $i >= 0 ; $i--) {
            if ($self->[$i] eq $obj) {
                CORE::splice(@$self, $i, 1);
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    *remove_last = \&delete_last;

    sub delete {
        my ($self, $obj) = @_;

        for (my $i = $#$self ; $i >= 0 ; --$i) {
            if ($self->[$i] eq $obj) {
                CORE::splice(@$self, $i, 1);
            }
        }

        $self;
    }

    *remove = \&delete;

    sub delete_if {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        for (my $i = 0 ; $i <= $#$self ; $i++) {
            if ($block->run($self->[$i])) {
                CORE::splice(@$self, $i--, 1);
            }
        }

        $self;
    }

    *remove_if = \&delete_if;
    *remove_by = \&delete_if;
    *delete_by = \&delete_if;

    sub extract_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        my @extracted;
        for (my $i = 0 ; $i <= $#$self ; $i++) {
            if ($block->run($self->[$i])) {
                CORE::push(@extracted, CORE::splice(@$self, $i--, 1));
            }
        }

        bless \@extracted;
    }

    sub extract_first_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        foreach my $i (0 .. $#$self) {
            if ($block->run($self->[$i])) {
                return CORE::splice(@$self, $i--, 1);
            }
        }

        return undef;
    }

    sub extract_last_by {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        for (my $i = $#$self ; $i >= 0 ; --$i) {
            if ($block->run($self->[$i])) {
                return CORE::splice(@$self, $i, 1);
            }
        }

        return undef;
    }

    sub delete_first_if {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        foreach my $i (0 .. $#$self) {
            if ($block->run($self->[$i])) {
                CORE::splice(@$self, $i, 1);
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    *remove_first_if = \&delete_first_if;
    *remove_first_by = \&delete_first_if;
    *delete_first_by = \&delete_first_if;

    sub delete_last_if {
        my ($self, $block) = @_;

        $block //= Sidef::Types::Block::Block::IDENTITY;

        for (my $i = $#$self ; $i >= 0 ; --$i) {
            if ($block->run($self->[$i])) {
                CORE::splice(@$self, $i, 1);
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    *remove_last_if = \&delete_last_if;
    *remove_last_by = \&delete_last_if;
    *delete_last_by = \&delete_last_if;

    sub to_list { @{$_[0]} }

    sub getopt {
        my ($self, %opts) = @_;

        state $x = require Getopt::Long;

        Getopt::Long::Configure('no_ignore_case');

        my @argv = map { "$_" } @$self;
        my @opts = CORE::keys %opts;

        my %parsed;
        Getopt::Long::GetOptionsFromArray(\@argv, \%parsed, @opts);

        my %lookup = map {
            my ($name) = Getopt::Long::ParseOptionSpec($_, \my %info);
            defined($name) ? ($name => {obj => $opts{$_}, type => $info{$name}[0]}) : ();
        } @opts;

        foreach my $key (CORE::keys %parsed) {

            my $rec  = $lookup{$key};
            my $obj  = $rec->{obj};
            my $type = $rec->{type};

            if (ref($obj) eq 'REF' or ref($obj) eq 'SCALAR') {
                my $ref = ref($$obj);

                # Determine the type for undefined references
                if ($ref eq '') {
                    if ($type eq 'i' or $type eq 'f') {
                        $ref = 'Sidef::Types::Number::Number';
                    }
                    elsif ($type eq '') {
                        $ref = 'Sidef::Types::Bool::Bool';
                    }
                    else {
                        $ref = 'Sidef::Types::String::String';
                    }
                }

                if (   $ref eq 'Sidef::Types::String::String'
                    or $ref eq 'Sidef::Types::Number::Number') {
                    $$obj = $ref->new($parsed{$key});
                }
                elsif ($ref eq 'Sidef::Types::Bool::Bool') {
                    $$obj =
                      $parsed{$key}
                      ? Sidef::Types::Bool::Bool::TRUE
                      : Sidef::Types::Bool::Bool::FALSE;
                }
                else {
                    if ($type eq '') {
                        $$obj = $ref->new(
                                          $parsed{$key}
                                          ? Sidef::Types::Bool::Bool::TRUE
                                          : Sidef::Types::Bool::Bool::FALSE
                                         );
                    }
                    elsif ($type eq 'i' or $type eq 'f') {
                        $$obj = $ref->new(Sidef::Types::Number::Number->new($parsed{$key}));
                    }
                    else {
                        $$obj = $ref->new(Sidef::Types::String::String->new($parsed{$key}));
                    }
                }
            }
            else {
                $obj->call();
            }
        }

        bless [map { Sidef::Types::String::String->new($_) } @argv];
    }

    sub _dump {
        my %addr;    # keeps track of dumped objects

        my $sub = sub {
            my ($obj) = @_;

            my $refaddr = Scalar::Util::refaddr($obj);

            exists($addr{$refaddr})
              and return $addr{$refaddr};

            $addr{$refaddr} = "Array(#`($refaddr)...)";

            my $s;

            '['
              . CORE::join(', ', map { ref($_) && ($s = UNIVERSAL::can($_, 'dump')) ? $s->($_) : ($_ // 'nil') } @$obj) . ']';
        };

        local *Sidef::Types::Array::Array::dump = $sub;
        $sub->($_[0]);
    }

    sub dump {
        Sidef::Types::String::String->new($_[0]->_dump);
    }

    *to_s   = \&dump;
    *to_str = \&dump;

    sub to_hash {
        my ($self) = @_;
        Sidef::Types::Hash::Hash->new(@$self);
    }

    *to_h = \&to_hash;

    sub to_a {
        $_[0];
    }

    *to_array = \&to_a;

    sub to_set {
        my ($self) = @_;
        Sidef::Types::Set::Set->new(@$self);
    }

    sub to_bag {
        my ($self) = @_;
        Sidef::Types::Set::Bag->new(@$self);
    }

    sub to_matrix {
        my ($self) = @_;
        Sidef::Types::Array::Matrix->new(@$self);
    }

    *to_m = \&to_matrix;

    sub to_vector {
        my ($self) = @_;
        Sidef::Types::Array::Vector->new(@$self);
    }

    *to_v = \&to_vector;

    {
        no strict 'refs';

        *{__PACKAGE__ . '::' . '&'}   = \&and;
        *{__PACKAGE__ . '::' . '*'}   = \&mul;
        *{__PACKAGE__ . '::' . '**'}  = \&mpow;
        *{__PACKAGE__ . '::' . '<<'}  = \&push;
        *{__PACKAGE__ . '::' . '«'}   = \&push;
        *{__PACKAGE__ . '::' . '>>'}  = \&pop;
        *{__PACKAGE__ . '::' . '»'}   = \&pop;
        *{__PACKAGE__ . '::' . '|Z>'} = \&pipeline_zip_op;
        *{__PACKAGE__ . '::' . '|X>'} = \&pipeline_cross_op;
        *{__PACKAGE__ . '::' . '|>>'} = \&pipeline_map_op;
        *{__PACKAGE__ . '::' . '|'}   = \&or;
        *{__PACKAGE__ . '::' . '^'}   = \&xor;
        *{__PACKAGE__ . '::' . '+'}   = \&add;
        *{__PACKAGE__ . '::' . '-'}   = \&sub;
        *{__PACKAGE__ . '::' . '=='}  = \&eq;
        *{__PACKAGE__ . '::' . '<'}   = \&lt;
        *{__PACKAGE__ . '::' . '<='}  = \&le;
        *{__PACKAGE__ . '::' . '≤'}   = \&le;
        *{__PACKAGE__ . '::' . '>'}   = \&gt;
        *{__PACKAGE__ . '::' . '≥'}   = \&ge;
        *{__PACKAGE__ . '::' . '>='}  = \&ge;
        *{__PACKAGE__ . '::' . '!='}  = \&ne;
        *{__PACKAGE__ . '::' . '≠'}   = \&ne;
        *{__PACKAGE__ . '::' . '<=>'} = \&cmp;
        *{__PACKAGE__ . '::' . '/'}   = \&div;
        *{__PACKAGE__ . '::' . '÷'}   = \&div;
        *{__PACKAGE__ . '::' . '...'} = \&to_list;
        *{__PACKAGE__ . '::' . '∋'}   = \&contains;
        *{__PACKAGE__ . '::' . '∌'}   = sub { $_[0]->contains($_[1])->not };
    }

};

1
