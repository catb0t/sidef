package Sidef::Types::Array::Array {

    use utf8;
    use 5.016;

    use parent qw(
      Sidef::Object::Object
      );

    use overload
      q{""}   => \&dump,
      q{0+}   => sub { scalar(@{$_[0]}) },
      q{bool} => sub { scalar(@{$_[0]}) };

    use Sidef::Types::Number::Number;

    sub new {
        @_ == 2 && ref($_[1]) eq 'ARRAY'
          ? bless($_[1], __PACKAGE__)
          : bless [@_[1 .. $#_]], __PACKAGE__;
    }

    *call = \&new;

    sub get_value {
        my ($self) = @_;

        my @array;
        foreach my $item (@{$self}) {
            if (index(ref($item), 'Sidef::') == 0) {
                CORE::push(@array, $item->get_value);
            }
            else {
                CORE::push(@array, $item);
            }
        }

        \@array;
    }

    sub unroll_operator {
        my ($self, $operator, $arg) = @_;

        $operator = "$operator" if ref($operator);

        my @array;
        if (defined $arg) {
            my $argc  = @{$arg};
            my $selfc = @{$self};
            my $max   = $argc > $selfc ? $argc - 1 : $selfc - 1;
            foreach my $i (0 .. $max) {
                CORE::push(@array, $self->[$i % $selfc]->$operator($arg->[$i % $argc]));
            }
        }
        else {
            foreach my $i (0 .. $#{$self}) {
                CORE::push(@array, $self->[$i]->$operator);
            }
        }

        $self->new(\@array);
    }

    sub map_operator {
        my ($self, $operator, @args) = @_;

        $operator = "$operator" if ref($operator);

        my @array;
        foreach my $i (0 .. $#{$self}) {
            CORE::push(@array, $self->[$i]->$operator(@args));
        }

        $self->new(\@array);
    }

    sub pam_operator {
        my ($self, $operator, $arg) = @_;

        $operator = "$operator" if ref($operator);

        my @array;
        foreach my $i (0 .. $#{$self}) {
            CORE::push(@array, $arg->$operator($self->[$i]));
        }

        $self->new(\@array);
    }

    sub reduce_operator {
        my ($self, $operator) = @_;

        $operator = "$operator" if ref($operator);
        (my $end = $#{$self}) >= 0 || return;

        my $x = $self->[0];
        foreach my $i (1 .. $end) {
            $x = $x->$operator($self->[$i]);
        }
        $x;
    }

    sub cross_operator {
        my ($self, $operator, $arg) = @_;

        $operator = "$operator" if ref($operator);

        my @array;
        if ($operator eq '') {
            foreach my $i (@{$self}) {
                foreach my $j (@{$arg}) {
                    CORE::push(@array, $self->new($i, $j));
                }
            }
        }
        else {
            foreach my $i (@{$self}) {
                foreach my $j (@{$arg}) {
                    CORE::push(@array, $i->$operator($j));
                }
            }
        }

        $self->new(\@array);
    }

    sub zip_operator {
        my ($self, $operator, $arg) = @_;

        $operator = "$operator" if ref($operator);

        my $self_len = $#{$self};
        my $arg_len  = $#{$arg};
        my $min      = $self_len < $arg_len ? $self_len : $arg_len;

        my @array;
        if ($operator eq '') {
            foreach my $i (0 .. $min) {
                CORE::push(@array, $self->new([$self->[$i], $arg->[$i]]));
            }
        }
        else {
            foreach my $i (0 .. $min) {
                CORE::push(@array, $self->[$i]->$operator($arg->[$i]));
            }
        }

        $self->new(\@array);
    }

    sub mul {
        my ($self, $num) = @_;

        {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $num = $num->get_value;
        }

        $self->new([(@{$self}) x $num]);
    }

    sub div {
        my ($self, $num) = @_;

        my @obj = @{$self};

        my @array;
        my $len = @obj / do {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $num->get_value;
        };

        my $i   = 1;
        my $pos = $len;
        while (@obj) {
            my $j = $pos - $i * int($len);
            $pos -= $j if $j >= 1;
            CORE::push(@array, $self->new([splice @obj, 0, $len + $j]));
            $pos += $len;
            $i++;
        }

        $self->new(\@array);
    }

    sub or {
        my ($self, $array) = @_;

        #$self->xor($array)->concat($self->and($array));
        $self->concat($array)->uniq;
    }

    sub xor {
        my ($self, $array) = @_;

        #$self->diff($array)->concat($array->diff($self));
        $self->concat($array)->diff($self->and($array));
    }

    sub and {
        my ($self, $array) = @_;

        my @s1 = sort { $a cmp $b } @{$self};
        my @s2 = sort { $a cmp $b } @{$array};

        my $i = 0;
        my $j = 0;

        my $end1 = @s1;
        my $end2 = @s2;

        my ($cmp, @new);
        while ($i < $end1 and $j < $end2) {

            $cmp = ($s1[$i] cmp $s2[$j]);

            if ($cmp eq Sidef::Types::Number::Number::MONE) {
                ++$i;
            }
            elsif ($cmp eq Sidef::Types::Number::Number::ONE) {
                ++$j;
            }
            else {
                push @new, $s1[$i];
                ++$i;
                ++$j;
            }
        }

        $self->new(\@new);
    }

    sub is_empty {
        my ($self) = @_;
        ($#{$self} == -1) ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub diff {
        my ($self, $array) = @_;

        my @s1 = sort { $a cmp $b } @{$self};
        my @s2 = sort { $a cmp $b } @{$array};

        my $i = 0;
        my $j = 0;

        my $end1 = @s1;
        my $end2 = @s2;

        my ($cmp, @new);
        while ($i < $end1 and $j < $end2) {

            $cmp = $s1[$i] cmp $s2[$j];

            if ($cmp eq Sidef::Types::Number::Number::MONE) {
                push @new, $s1[$i];
                ++$i;
            }
            elsif ($cmp eq Sidef::Types::Number::Number::ONE) {
                ++$j;
            }
            else {
                1 while (++$i < $end1 and $s1[$i] eq $s2[$j]);
            }
        }

        if ($i < $end1) {
            push @new, @s1[$i .. $#s1];
        }

        $self->new(\@new);
    }

    sub concat {
        my ($self, $arg) = @_;

        eval { $arg->isa('ARRAY') }
          ? $self->new(@{$self}, @{$arg})
          : $self->new(@{$self}, $arg);
    }

    sub levenshtein {
        my ($self, $arg) = @_;

        my @s = @{$self};
        my @t = @{$arg};

        my $len1 = scalar(@s);
        my $len2 = scalar(@t);

        state $x = require List::Util;

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

        my @s = @{$self};
        my @t = @{$arg};

        my $s_len = @s;
        my $t_len = @t;

        if ($s_len == 0 and $t_len == 0) {
            return 1;
        }

        state $x = require List::Util;
        my $match_distance = int(List::Util::max($s_len, $t_len) / 2) - 1;

        my @s_matches;
        my @t_matches;

        my $matches = 0;
        foreach my $i (0 .. $#s) {

            my $start = List::Util::max(0, $i - $match_distance);
            my $end = List::Util::min($i + $match_distance + 1, $t_len);

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

    sub combinations {
        my ($self, $k, $block) = @_;

        {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $k = $k->get_value;
        }

        if (defined($block)) {

            if ($k == 0) {
                $block->run($self->new);
                return $self;
            }

            return if $k < 0;

            my $n = @{$self};
            return $self if ($k > $n or $n == 0);

            my @c = (0 .. $k - 1);

            while (1) {
                $block->run($self->new(@{$self}[@c]));
                next if ($c[$k - 1]++ < $n - 1);
                my $i = $k - 2;
                $i-- while ($i >= 0 && $c[$i] >= $n - ($k - $i));
                last if $i < 0;
                $c[$i]++;
                while (++$i < $k) { $c[$i] = $c[$i - 1] + 1; }
            }

            return $self;
        }

        return $self->new($self->new) if $k == 0;
        return if $k < 0;

        my $n = @{$self};
        return $self->new if ($k > $n or $n == 0);

        my @c = (0 .. $k - 1);
        my @result;

        while (1) {
            CORE::push(@result, $self->new(@{$self}[@c]));
            next if ($c[$k - 1]++ < $n - 1);
            my $i = $k - 2;
            $i-- while ($i >= 0 && $c[$i] >= $n - ($k - $i));
            last if $i < 0;
            $c[$i]++;
            while (++$i < $k) { $c[$i] = $c[$i - 1] + 1; }
        }

        $self->new(\@result);
    }

    *combination = \&combinations;

    sub count {
        my ($self, $obj) = @_;

        my $counter = 0;
        if (ref($obj) eq 'Sidef::Types::Block::Block') {

            foreach my $item (@{$self}) {
                if ($obj->run($item)) {
                    ++$counter;
                }
            }

            return Sidef::Types::Number::Number::_new_uint($counter);
        }

        foreach my $item (@{$self}) {
            $item eq $obj and $counter++;
        }

        Sidef::Types::Number::Number::_new_uint($counter);
    }

    *count_by = \&count;

    sub eq {
        my ($self, $array) = @_;

        if ($#{$self} != $#{$array}) {
            return (Sidef::Types::Bool::Bool::FALSE);
        }

        foreach my $i (0 .. $#{$self}) {
            my ($x, $y) = ($self->[$i], $array->[$i]);
            $x eq $y
              or return (Sidef::Types::Bool::Bool::FALSE);
        }

        (Sidef::Types::Bool::Bool::TRUE);
    }

    sub ne {
        my ($self, $array) = @_;
        $self->eq($array)->neg;
    }

    sub zip {
        my ($self, @arrays) = @_;

        my @new_array;
        foreach my $i (0 .. $#{$self}) {

            my @tmp_array = ($self->[$i]);
            foreach my $array (@arrays) {
                CORE::push(@tmp_array, $array->[$i]);
            }

            CORE::push(@new_array, $self->new(\@tmp_array));
        }

        $self->new(\@new_array);
    }

    sub mzip {
        my ($self, $array) = @_;

        my $arr_max = @{$array};

        my @new_array;
        foreach my $i (0 .. $#{$self}) {
            CORE::push(@new_array, $self->[$i], $array->[$i % $arr_max]);
        }

        $self->new(\@new_array);
    }

    sub make {
        my ($self, $size, $type) = @_;
        $self->new(
            [
             ($type) x do {
                 local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
                 $size->get_value;
               }
            ]
        );
    }

    sub _min_max {
        my ($self, $value) = @_;

        @{$self} || return;

        my $item = $self->[0];
        foreach my $i (1 .. $#{$self}) {
            my $val = $self->[$i];
            $item = $val if (($val cmp $item) eq $value);
        }

        $item;
    }

    sub max {
        $_[0]->_min_max(Sidef::Types::Number::Number::ONE);
    }

    sub min {
        $_[0]->_min_max(Sidef::Types::Number::Number::MONE);
    }

    sub minmax {
        my ($self) = @_;
        ($self->min, $self->max);
    }

    sub sum {
        defined($_[1])
          ? do {
            my $sum = $_[1];
            state $method = '+';
            foreach my $obj (@{$_[0]}) {
                $sum = $sum->$method($obj);
            }
            $sum;
          }
          : $_[0]->reduce_operator('+');
    }

    *collapse = \&sum;

    sub prod {
        defined($_[1])
          ? do {
            my $prod = $_[1];
            state $method = '*';
            foreach my $obj (@{$_[0]}) {
                $prod = $prod->$method($obj);
            }
            $prod;
          }
          : $_[0]->reduce_operator('*');
    }

    *product = \&prod;

    sub _min_max_by {
        my ($self, $code, $value) = @_;

        @{$self} || return;

        my @pairs = map { [$_, scalar $code->run($_)] } @{$self};
        my $item = $pairs[0];

        foreach my $i (1 .. $#pairs) {
            my $val = $pairs[$i][1];
            $item = $pairs[$i] if (($val cmp $item->[1]) eq $value);
        }

        $item->[0];
    }

    sub max_by {
        $_[0]->_min_max_by($_[1], Sidef::Types::Number::Number::ONE);
    }

    sub min_by {
        $_[0]->_min_max_by($_[1], Sidef::Types::Number::Number::MONE);
    }

    sub swap {
        my ($self, $i, $j) = @_;
        @{$self}[$i, $j] = @{$self}[$j, $i];
        $self;
    }

    sub change_to {
        my ($self, $arg) = @_;
        @{$self} = @{$arg};
        $self;
    }

    sub first {
        my ($self, $arg) = @_;

        if (defined $arg) {

            if (ref($arg) eq 'Sidef::Types::Block::Block') {
                return $self->first_by($arg);
            }

            my $max = $#{$self};
            $arg = do {
                local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
                $arg->get_value;
              }
              - 1;
            return $self->new(@{$self}[0 .. ($arg > $max ? $max : $arg)]);
        }

        @{$self} ? $self->[0] : ();
    }

    sub last {
        my ($self, $arg) = @_;

        if (defined $arg) {

            if (ref($arg) eq 'Sidef::Types::Block::Block') {
                return $self->last_by($arg);
            }

            my $from = @{$self} - do {
                local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
                $arg->get_value;
            };
            return $self->new(@{$self}[($from < 0 ? 0 : $from) .. $#{$self}]);
        }

        @{$self} ? $self->[-1] : ();
    }

    sub _flatten {    # this exists for performance reasons
        my ($self) = @_;

        my @array;
        foreach my $i (0 .. $#{$self}) {
            my $item = $self->[$i];
            CORE::push(@array, ref($item) eq ref($self) ? $item->_flatten : $item);
        }

        @array;
    }

    sub flatten {
        my ($self) = @_;

        my @new_array;
        foreach my $i (0 .. $#{$self}) {
            my $item = $self->[$i];
            CORE::push(@new_array, ref($item) eq ref($self) ? ($item->_flatten) : $item);
        }

        $self->new(\@new_array);
    }

    *flat = \&flatten;

    sub exists {
        my ($self, $index) = @_;
        (
         exists $self->[
           do {
               local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
               $index->get_value;
           }
         ]
        ) ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    *has_index = \&exists;

    sub defined {
        my ($self, $index) = @_;
        (
         defined(
             $self->[
               do {
                   local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
                   $index->get_value;
               }
             ]
         )
        ) ? (Sidef::Types::Bool::Bool::TRUE) : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub items {
        my ($self, @indices) = @_;
        $self->new([map { exists($self->[$_]) ? $self->[$_] : undef } @indices]);
    }

    sub item {
        my ($self, $index) = @_;
        exists($self->[$index]) ? $self->[$index] : ();
    }

    sub fetch {
        my ($self, $index, $default) = @_;
        exists($self->[$index]) ? $self->[$index] : $default;
    }

    sub dig {
        my ($self, $key, @keys) = @_;

        my $value = $self->fetch($key) // return;

        foreach my $key (@keys) {
            $value = $value->fetch($key) // return;
        }

        $value;
    }

    sub _slice {
        my ($self, $from, $to) = @_;

        my $max = @{$self};

        {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $from = defined($from) ? ($from->get_value) : 0;
            $to   = defined($to)   ? ($to->get_value)   : $max - 1;
        }

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

        @{$self}[$from .. $to];
    }

    sub ft {
        my ($self) = @_;
        $self->new([_slice(@_)]);
    }

    *slice = \&ft;

    sub each {
        my ($self, $code) = @_;

        foreach my $item (@{$self}) {
            $code->run($item);
        }

        $self;
    }

    *for     = \&each;
    *foreach = \&each;

    sub each_slice {
        my ($self, $n, $code) = @_;

        {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $n = $n->get_value;
        }

        my $end = @{$self};
        for (my $i = $n - 1 ; $i < $end ; $i += $n) {
            $code->run($self->new([@{$self}[$i - ($n - 1) .. $i]]));
        }

        my $mod = $end % $n;
        if ($mod != 0) {
            $code->run($self->new([@{$self}[$end - $mod .. $end - 1]]));
        }

        $self;
    }

    sub slices {
        my ($self, $n) = @_;

        {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $n = $n->get_value;
        }

        my @slices;
        my $end = @{$self};
        for (my $i = $n - 1 ; $i < $end ; $i += $n) {
            CORE::push(@slices, $self->new([@{$self}[$i - ($n - 1) .. $i]]));
        }

        my $mod = $end % $n;
        if ($mod != 0) {
            CORE::push(@slices, $self->new([@{$self}[$end - $mod .. $end - 1]]));
        }

        $self->new(\@slices);
    }

    sub each_cons {
        my ($self, $n, $code) = @_;

        {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $n = $n->get_value;
        }

        foreach my $i ($n - 1 .. $#{$self}) {
            $code->run($self->new([@{$self}[$i - $n + 1 .. $i]]));
        }

        $self;
    }

    sub each_index {
        my ($self, $code) = @_;

        foreach my $i (0 .. $#{$self}) {
            $code->run(Sidef::Types::Number::Number::_new_uint($i));
        }

        $self;
    }

    *each_key = \&each_index;

    sub each_kv {
        my ($self, $code) = @_;

        foreach my $i (0 .. $#{$self}) {
            $code->run(Sidef::Types::Number::Number::_new_uint($i), $self->[$i]);
        }

        $self;
    }

    sub map {
        my ($self, $code) = @_;

        my @array;
        foreach my $item (@{$self}) {
            CORE::push(@array, $code->run($item));
        }

        $self->new(\@array);
    }

    *collect = \&map;

    sub map_kv {
        my ($self, $code) = @_;

        my @arr;
        foreach my $i (0 .. $#{$self}) {
            CORE::push(@arr, $code->run(Sidef::Types::Number::Number::_new_uint($i), $self->[$i]));
        }

        $self->new(\@arr);
    }

    *collect_kv = \&map_kv;

    sub flat_map {
        my ($self, $code) = @_;

        my @array;
        foreach my $item (@{$self}) {
            CORE::push(@array, @{scalar $code->run($item)});
        }

        $self->new(\@array);
    }

    sub grep {
        my ($self, $obj) = @_;

        my @array;
        if (ref($obj) eq 'Sidef::Types::Regex::Regex') {
            foreach my $item (@{$self}) {
                CORE::push(@array, $item) if $obj->match($item);
            }
        }
        else {
            foreach my $item (@{$self}) {
                CORE::push(@array, $item) if $obj->run($item);
            }
        }

        $self->new(\@array);
    }

    *filter = \&grep;
    *select = \&grep;

    sub grep_kv {
        my ($self, $code) = @_;

        my @arr;
        foreach my $i (0 .. $#{$self}) {
            CORE::push(@arr, $self->[$i]) if $code->run(Sidef::Types::Number::Number::_new_uint($i), $self->[$i]);
        }

        $self->new(\@arr);
    }

    *filter_kv = \&grep_kv;
    *select_kv = \&grep_kv;

    sub group_by {
        my ($self, $code) = @_;

        my $hash = Sidef::Types::Hash::Hash->new;
        foreach my $item (@{$self}) {
            my $key = $code->run(my $val = $item);
            my $str_key = "$key";
            exists($hash->{$str_key}) or do { $hash->{$str_key} = $self->new };
            CORE::push(@{$hash->{$str_key}}, $val);
        }

        $hash;
    }

    sub iter {
        my ($self) = @_;

        my $i = 0;
        Sidef::Types::Block::Block->new(
            code => sub {
                my $result = exists($self->[$i]) ? $self->[$i] : return;
                ++$i;
                $result;
            }
        );
    }

    sub freq {
        my ($self, $code) = @_;

        if (defined($code)) {
            return $self->freq_by($code);
        }

        my %hash;
        foreach my $item (@{$self}) {
            $hash{$item}++;
        }

        foreach my $key (keys %hash) {
            $hash{$key} = Sidef::Types::Number::Number::_new_uint($hash{$key});
        }

        Sidef::Types::Hash::Hash->new(%hash);
    }

    sub freq_by {
        my ($self, $code) = @_;

        my %hash;
        foreach my $item (@{$self}) {
            $hash{$code->run($item)}++;
        }

        foreach my $key (keys %hash) {
            $hash{$key} = Sidef::Types::Number::Number::_new_uint($hash{$key});
        }

        Sidef::Types::Hash::Hash->new(%hash);
    }

    sub first_by {
        my ($self, $code) = @_;
        foreach my $val (@{$self}) {
            return $val if $code->run($val);
        }
        return;
    }

    *find = \&first_by;

    sub last_by {
        my ($self, $code) = @_;
        for (my $i = $#{$self} ; $i >= 0 ; --$i) {
            return $self->[$i] if $code->run($self->[$i]);
        }
        return;
    }

    sub any {
        my ($self, $code) = @_;

        foreach my $val (@{$self}) {
            $code->run($val)
              && return (Sidef::Types::Bool::Bool::TRUE);
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    sub all {
        my ($self, $code) = @_;

        @{$self} || return (Sidef::Types::Bool::Bool::FALSE);

        foreach my $val (@{$self}) {
            $code->run($val)
              || return (Sidef::Types::Bool::Bool::FALSE);
        }

        (Sidef::Types::Bool::Bool::TRUE);
    }

    sub assign_to {
        my ($self, @vars) = @_;

        my @values = splice(@{$self}, 0, $#vars + 1);

        for my $i (0 .. $#vars) {
            if (exists $values[$i]) {
                ${$vars[$i]} = $values[$i];
            }
        }

        $self->new(\@values);
    }

    sub index {
        my ($self, $obj) = @_;

        if (@_ > 1) {

            if (ref($obj) eq 'Sidef::Types::Block::Block') {
                foreach my $i (0 .. $#{$self}) {
                    $obj->run($self->[$i])
                      && return Sidef::Types::Number::Number::_new_uint($i);
                }
                return Sidef::Types::Number::Number::_new_int(-1);
            }

            foreach my $i (0 .. $#{$self}) {
                $self->[$i] eq $obj
                  and return Sidef::Types::Number::Number::_new_uint($i);
            }

            return Sidef::Types::Number::Number::_new_int(-1);
        }

        Sidef::Types::Number::Number::_new_int(@{$self} ? 0 : -1);
    }

    *index_by    = \&index;
    *first_index = \&index;

    sub rindex {
        my ($self, $obj) = @_;

        if (@_ > 1) {
            if (ref($obj) eq 'Sidef::Types::Block::Block') {
                for (my $i = $#{$self} ; $i >= 0 ; $i--) {
                    $obj->run($self->[$i])
                      && return Sidef::Types::Number::Number::_new_uint($i);
                }

                return Sidef::Types::Number::Number::_new_int(-1);
            }

            for (my $i = $#{$self} ; $i >= 0 ; $i--) {
                $self->[$i] eq $obj
                  and return Sidef::Types::Number::Number::_new_uint($i);
            }

            return Sidef::Types::Number::Number::_new_int(-1);
        }

        Sidef::Types::Number::Number::_new_int($#{$self});
    }

    *rindex_by  = \&rindex;
    *last_index = \&rindex;

    sub pairmap {
        my ($self, $obj) = @_;

        my $end = @{$self} || return $self->new;

        my @array;
        for (my $i = 1 ; $i < $end ; $i += 2) {
            CORE::push(@array, scalar $obj->run(@{$self}[$i - 1, $i]));
        }

        $self->new(\@array);
    }

    sub shuffle {
        my ($self) = @_;
        state $x = require List::Util;
        $self->new(List::Util::shuffle(@{$self}));
    }

    sub best_shuffle {
        my ($s) = @_;
        my ($t) = $s->shuffle;

        foreach my $i (0 .. $#{$s}) {
            foreach my $j (0 .. $#{$s}) {
                $i != $j
                  && !($t->[$i] eq $s->[$j])
                  && !($t->[$j] eq $s->[$i])
                  && do {
                    @{$t}[$i, $j] = @{$t}[$j, $i];
                    last;
                  }
            }
        }

        $t;
    }

    *bshuffle = \&best_shuffle;

    sub pair_with {
        my ($self, @args) = @_;
        Sidef::Types::Array::MultiArray->new($self, @args);
    }

    sub reduce {
        my ($self, $obj) = @_;

        if (ref($obj) eq 'Sidef::Types::Block::Block') {
            (my $end = $#{$self}) >= 0 || return;

            my $x = $self->[0];
            foreach my $i (1 .. $end) {
                $x = $obj->run($x, $self->[$i]);
            }

            return $x;
        }

        $self->reduce_operator("$obj");
    }

    *inject = \&reduce;

    sub length {
        my ($self) = @_;
        Sidef::Types::Number::Number::_new_uint(scalar @{$self});
    }

    *len  = \&length;    # alias
    *size = \&length;

    sub end {
        my ($self) = @_;
        Sidef::Types::Number::Number::_new_int($#{$self});
    }

    *offset = \&end;

    sub resize {
        my ($self, $num) = @_;
        $#{$self} = do {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $num->get_value;
        };
        $num;
    }

    *resize_to = \&resize;

    sub rand {
        my ($self, $amount) = @_;

        if (defined $amount) {
            {
                local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
                $amount = $amount->get_value;
            }
            return $self->new([map { $self->[CORE::rand(scalar @{$self})] } 1 .. $amount]);
        }
        $self->[CORE::rand(scalar @{$self})];
    }

    *pick   = \&rand;
    *sample = \&rand;

    sub range {
        my ($self) = @_;
        Sidef::Types::Range::RangeNumber->__new__(
            from => ${(Sidef::Types::Number::Number::ZERO)},
            to   => do {
                my $r = Math::GMPq::Rmpq_init();
                my $i = $#{$self};
                $i < 0
                  ? Math::GMPq::Rmpq_set_si($r, $i, 1)
                  : Math::GMPq::Rmpq_set_ui($r, $i, 1);
                $r;
            },
            step => ${(Sidef::Types::Number::Number::ONE)},
                                                 );
    }

    sub indices {
        my ($self) = @_;
        $self->new([map { Sidef::Types::Number::Number::_new_uint($_) } 0 .. $#{$self}]);
    }

    *keys = \&indices;

    sub pairs {
        my ($self) = @_;
        $self->new(
            [map { Sidef::Types::Array::Pair->new(Sidef::Types::Number::Number::_new_uint($_), $self->[$_]) } 0 .. $#{$self}]);
    }

    sub insert {
        my ($self, $index, @objects) = @_;

        my $i = do {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $index->get_value;
        };

        if ($#{$self} < $i) {
            $#{$self} = $i - 1;
        }

        splice(@{$self}, $i, 0, @objects);
        $self;
    }

    sub unique {
        my ($self) = @_;

        my @sorted = do {
            my @arr;
            foreach my $i (0 .. $#{$self}) {
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

        $self->new([grep { defined } @unique]);
    }

    *uniq     = \&unique;
    *distinct = \&unique;

    sub last_unique {
        my ($self) = @_;

        my @sorted = do {
            my @arr;
            foreach my $i (0 .. $#{$self}) {
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

        $self->new([grep { defined } @unique]);
    }

    *last_uniq = \&last_unique;

    sub uniq_by {
        my ($self, $block) = @_;

        my @sorted = do {
            my @arr;
            my $i = -1;
            foreach my $item (@{$self}) {
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

        $self->new([grep { defined } @unique]);
    }

    *unique_by = \&uniq_by;

    sub last_uniq_by {
        my ($self, $block) = @_;

        my @sorted = do {
            my @arr;
            my $i = -1;
            foreach my $item (@{$self}) {
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

        $self->new([grep { defined } @unique]);
    }

    *last_unique_by = \&last_uniq_by;

    sub abbrev {
        my ($self, $block) = @_;

        my $tail     = {};                # some unique value
        my $callback = defined($block);

        my %table;
        foreach my $sub_array (@{$self}) {
            my $ref = \%table;
            foreach my $item (@{$sub_array}) {
                $ref = $ref->{$item} //= {};
            }
            $ref->{$tail} = $sub_array;
        }

        my @abbrev;
        sub {
            my ($hash) = @_;

            foreach my $key (my @keys = CORE::sort keys %{$hash}) {
                next if $key eq $tail;
                __SUB__->($hash->{$key});

                if ($#keys > 0) {
                    my $count = 0;
                    my $ref   = delete $hash->{$key};
                    while (my ($key) = CORE::each %{$ref}) {
                        if ($key eq $tail) {

                            if ($callback) {
                                $block->run($self->new([@{$ref->{$key}}[0 .. $#{$ref->{$key}} - $count]]));
                            }
                            else {
                                CORE::push(@abbrev, $self->new([@{$ref->{$key}}[0 .. $#{$ref->{$key}} - $count]]));
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

        $self->new(\@abbrev);
    }

    *abbreviations = \&abbrev;

    sub contains {
        my ($self, $obj) = @_;

        if (ref($obj) eq 'Sidef::Types::Block::Block') {
            foreach my $item (@{$self}) {
                if ($obj->run($item)) {
                    return (Sidef::Types::Bool::Bool::TRUE);
                }
            }

            return (Sidef::Types::Bool::Bool::FALSE);
        }

        foreach my $item (@{$self}) {
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

        foreach my $item (@{$self}) {
            if (ref($item) eq $ref || eval { $item->SUPER::isa($ref) }) {
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        return (Sidef::Types::Bool::Bool::FALSE);
    }

    sub contains_any {
        my ($self, $array) = @_;

        foreach my $item (@{$array}) {
            if ($self->contains($item)) {
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    sub contains_all {
        my ($self, $array) = @_;

        foreach my $item (@{$array}) {
            unless ($self->contains($item)) {
                return (Sidef::Types::Bool::Bool::FALSE);
            }
        }

        (Sidef::Types::Bool::Bool::TRUE);
    }

    sub shift {
        my ($self, $num) = @_;

        if (defined $num) {
            return $self->new(
                [
                 CORE::splice(
                     @{$self},
                     0,
                     do {
                         local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
                         $num->get_value;
                       }
                 )
                ]
            );
        }

        @{$self} || return;
        shift(@{$self});
    }

    *drop_first = \&shift;
    *drop_left  = \&shift;

    sub pop {
        my ($self, $num) = @_;

        if (defined $num) {
            {
                local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
                $num = $num->get_value;
            }

            $num = $num > $#{$self} ? 0 : @{$self} - $num;
            return $self->new([CORE::splice(@{$self}, $num)]);
        }

        @{$self} || return;
        pop(@{$self});
    }

    *drop_last  = \&pop;
    *drop_right = \&pop;

    sub pop_rand {
        my ($self) = @_;
        $#{$self} > -1 || return;
        CORE::splice(@{$self}, CORE::rand(scalar @{$self}), 1);
    }

    sub delete_index {
        my ($self, $offset) = @_;
        CORE::splice(
            @{$self},
            do {
                local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
                $offset->get_value;
            },
            1
                    );
    }

    *pop_at    = \&delete_index;
    *delete_at = \&delete_index;

    sub splice {
        my ($self, $offset, $length, @objects) = @_;

        {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $offset = defined($offset) ? $offset->get_value : 0;
            $length = defined($length) ? $length->get_value : scalar(@{$self});
        }

        $self->new([CORE::splice(@{$self}, $offset, $length, @objects)]);
    }

    sub take_right {
        my ($self, $amount) = @_;

        my $end = $#{$self};
        {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $amount = $amount->get_value;
            $amount = $end > ($amount - 1) ? $amount - 1 : $end;
        }
        $self->new([@{$self}[$end - $amount .. $end]]);
    }

    sub take_left {
        my ($self, $amount) = @_;

        my $end = $#{$self};
        {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $amount = $amount->get_value;
            $amount = $end > ($amount - 1) ? $amount - 1 : $end;
        }
        $self->new([@{$self}[0 .. $amount]]);
    }

    sub sort {
        my ($self, $code) = @_;

        if (defined $code) {
            return $self->new([CORE::sort { scalar $code->run($a, $b) } @{$self}]);
        }

        $self->new([CORE::sort { $a cmp $b } @{$self}]);
    }

    sub sort_by {
        my ($self, $code) = @_;
        $self->new([map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [$_, scalar $code->run($_)] } @{$self}]);
    }

    sub cmp {
        my ($self, $arg) = @_;

        my $l1 = $#{$self};
        my $l2 = $#{$arg};

        my $min = $l1 < $l2 ? $l1 : $l2;

        foreach my $i (0 .. $min) {

            my $obj1 = $self->[$i];
            my $obj2 = $arg->[$i];

            my $value = $obj1 cmp $obj2;

            if (ref($value)) {
                $value eq Sidef::Types::Number::Number::ZERO
                  or return $value;
            }
            elsif ($value != 0) {
                return ($value < 0 ? Sidef::Types::Number::Number::MONE : Sidef::Types::Number::Number::ONE);
            }
        }

            $l1 == $l2 ? Sidef::Types::Number::Number::ZERO
          : $l1 < $l2  ? Sidef::Types::Number::Number::MONE
          :              Sidef::Types::Number::Number::ONE;
    }

    # Insert an object between each element
    sub join_insert {
        my ($self, $delim_obj) = @_;

        @{$self} || return $self->new;

        my @array = $self->[0];
        foreach my $i (1 .. $#{$self}) {
            CORE::push(@array, $delim_obj, $self->[$i]);
        }
        $self->new(\@array);
    }

    sub permute {
        my ($self, $code) = @_;

        @{$self} || return $self;
        my @idx = 0 .. $#{$self};

        if (defined($code)) {
            my $perm;
            while (1) {
                $perm = $self->new([@{$self}[@idx]]);

                my $p = $#idx;
                --$p while $idx[$p - 1] > $idx[$p];

                my $q = $p or do {
                    $code->run($perm);
                    return $self;
                };

                CORE::push(@idx, CORE::reverse CORE::splice @idx, $p);
                ++$q while $idx[$p - 1] > $idx[$q];
                @idx[$p - 1, $q] = @idx[$q, $p - 1];

                $code->run($perm);
            }

            return;
        }

        my @array;
        while (1) {
            CORE::push(@array, $self->new([@{$self}[@idx]]));
            my $p = $#idx;
            --$p while $idx[$p - 1] > $idx[$p];
            my $q = $p or (return $self->new(\@array));
            CORE::push(@idx, CORE::reverse CORE::splice @idx, $p);
            ++$q while $idx[$p - 1] > $idx[$q];
            @idx[$p - 1, $q] = @idx[$q, $p - 1];
        }
    }

    *permutations = \&permute;
    *permutation  = \&permute;

    sub pack {
        my ($self, $format) = @_;
        Sidef::Types::String::String->new(CORE::pack("$format", @{$self}));
    }

    sub push {
        my ($self, @args) = @_;
        CORE::push(@{$self}, @args);
        $self;
    }

    *append = \&push;

    sub unshift {
        my ($self, @args) = @_;
        CORE::unshift(@{$self}, @args);
        $self;
    }

    *prepend = \&unshift;

    sub rotate {
        my ($self, $num) = @_;

        {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $num = $num->get_value;
        }

        $num %= ($#{$self} + 1);
        return $self->new([@{$self}]) if $num == 0;

        # Surprisingly, this is slower:
        # $self->new(@{$self}[$num .. $#{$self}], @{$self}[0 .. $num - 1]);

        # Surprisingly, this is 73% faster:
        my @array = @{$self};
        CORE::unshift(@array, CORE::splice(@array, $num));
        $self->new(\@array);
    }

    # Join the array as string
    sub join {
        my ($self, $delim, $block) = @_;
        $delim = defined($delim) ? "$delim" : '';

        if (defined $block) {
            return Sidef::Types::String::String->new(CORE::join($delim, map { scalar $block->run($_) } @{$self}));
        }

        Sidef::Types::String::String->new(CORE::join($delim, @{$self}));
    }

    sub join_bytes {
        my ($self, $encoding) = @_;
        state $x = require Encode;
        $encoding = defined($encoding) ? "$encoding" : 'UTF-8';
        Sidef::Types::String::String->new(
            eval {
                Encode::decode($encoding, CORE::join('', map { CORE::chr($_) } @{$self}));
              } // return
        );
    }

    *encode = \&join_bytes;

    sub reverse {
        my ($self) = @_;
        $self->new([CORE::reverse @{$self}]);
    }

    *reversed = \&reverse;    # alias

    sub to_hash {
        my ($self) = @_;
        Sidef::Types::Hash::Hash->new(@{$self});
    }

    *to_h = \&to_hash;

    sub copy {
        my ($self) = @_;

        my @array;
        my $sub;
        foreach my $item (@{$self}) {
            if (ref($item) and defined(eval { $sub = $item->SUPER::can('copy') })) {
                CORE::push(@array, $sub->($item));
            }
            else {
                CORE::push(@array, $item);
            }
        }

        $self->new(\@array);

        #state $x = require Storable;
        #Storable::dclone($self);           # this is buggy
    }

    sub delete_first {
        my ($self, $obj) = @_;

        foreach my $i (0 .. $#{$self}) {
            my $item = $self->[$i];
            if ($item eq $obj) {
                CORE::splice(@{$self}, $i, 1);
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    *remove_first = \&delete_first;

    sub delete_last {
        my ($self, $obj) = @_;

        for (my $i = $#{$self} ; $i >= 0 ; $i--) {
            my $item = $self->[$i];
            if ($item eq $obj) {
                CORE::splice(@{$self}, $i, 1);
                return (Sidef::Types::Bool::Bool::TRUE);
            }
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    *remove_last = \&delete_last;

    sub delete {
        my ($self, $obj) = @_;

        for (my $i = 0 ; $i <= $#{$self} ; $i++) {
            my $item = $self->[$i];
            if ($item eq $obj) {
                CORE::splice(@{$self}, $i--, 1);
            }
        }

        $self;
    }

    *remove = \&delete;

    sub delete_if {
        my ($self, $code) = @_;

        for (my $i = 0 ; $i <= $#{$self} ; $i++) {
            $code->run($self->[$i])
              && CORE::splice(@{$self}, $i--, 1);
        }

        $self;
    }

    *remove_if = \&delete_if;

    sub delete_first_if {
        my ($self, $code) = @_;

        foreach my $i (0 .. $#{$self}) {
            my $item = $self->[$i];
            $code->run($item) && do {
                CORE::splice(@{$self}, $i, 1);
                return (Sidef::Types::Bool::Bool::TRUE);
            };
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    *remove_first_if = \&delete_first_if;

    sub delete_last_if {
        my ($self, $code) = @_;

        for (my $i = $#{$self} ; $i >= 0 ; --$i) {
            my $item = $self->[$i];
            $code->run($item) && do {
                CORE::splice(@{$self}, $i, 1);
                return (Sidef::Types::Bool::Bool::TRUE);
              }
        }

        (Sidef::Types::Bool::Bool::FALSE);
    }

    *remove_last_if = \&delete_last_if;

    sub to_list { @{$_[0]} }
    *as_list = \&to_list;

    sub dump {
        my ($self) = @_;

        Sidef::Types::String::String->new(
            '[' . CORE::join(
                ', ',
                map {
                    my $item = defined($self->[$_]) ? $self->[$_] : 'nil';
                    ref($item) && defined(eval { $item->can('dump') }) ? $item->dump() : $item;
                  } 0 .. $#{$self}
              )
              . ']'
        );
    }

    sub to_s {
        my ($self) = @_;
        Sidef::Types::String::String->new(CORE::join(' ', @{$self}));
    }

    {
        no strict 'refs';

        *{__PACKAGE__ . '::' . '&'}   = \&and;
        *{__PACKAGE__ . '::' . '*'}   = \&mul;
        *{__PACKAGE__ . '::' . '<<'}  = \&append;
        *{__PACKAGE__ . '::' . '«'}  = \&append;
        *{__PACKAGE__ . '::' . '>>'}  = \&assign_to;
        *{__PACKAGE__ . '::' . '»'}  = \&assign_to;
        *{__PACKAGE__ . '::' . '|'}   = \&or;
        *{__PACKAGE__ . '::' . '^'}   = \&xor;
        *{__PACKAGE__ . '::' . '+'}   = \&concat;
        *{__PACKAGE__ . '::' . '-'}   = \&diff;
        *{__PACKAGE__ . '::' . '=='}  = \&eq;
        *{__PACKAGE__ . '::' . '!='}  = \&ne;
        *{__PACKAGE__ . '::' . '<=>'} = \&cmp;
        *{__PACKAGE__ . '::' . ':'}   = \&pair_with;
        *{__PACKAGE__ . '::' . '/'}   = \&div;
        *{__PACKAGE__ . '::' . '...'} = \&to_list;

        *{__PACKAGE__ . '::' . '++'} = sub {
            my ($self, $obj) = @_;
            CORE::push(@{$self}, $obj);
            $self;
        };

        *{__PACKAGE__ . '::' . '--'} = sub {
            my ($self) = @_;
            CORE::pop(@{$self});
            $self;
        };
    }

};

1
