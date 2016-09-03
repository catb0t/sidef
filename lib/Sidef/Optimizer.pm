package Sidef::Optimizer {

    use 5.014;
    use Scalar::Util qw(refaddr);

    use constant {
                  STRING      => 'Sidef::Types::String::String',
                  NUMBER      => 'Sidef::Types::Number::Number',
                  REGEX       => 'Sidef::Types::Regex::Regex',
                  BOOL        => 'Sidef::Types::Bool::Bool',
                  ARRAY       => 'Sidef::Types::Array::Array',
                  COMPLEX     => 'Sidef::Types::Number::Complex',
                  NUMBER_DT   => 'Sidef::DataTypes::Number::Number',
                  STRING_DT   => 'Sidef::DataTypes::String::String',
                  COMPLEX_DT  => 'Sidef::DataTypes::Number::Complex',
                  REGEX_DT    => 'Sidef::DataTypes::Regex::Regex',
                  RANGENUM_DT => 'Sidef::DataTypes::Range::RangeNumber',
                  BACKTICK_DT => 'Sidef::DataTypes::Glob::Backtick',
                 };

    my %cache;
    {

        sub methods {
            my ($package, @names) = @_;
            my $module = ($cache{$package} //= (($package =~ s{::}{/}gr) . '.pm'));
            exists($INC{$module}) || require($module);
            map {
                $cache{$package, $_} //= do {
                    defined(my $method = UNIVERSAL::can($package, $_))
                      or die "[ERROR] Invalid method $package: $_";
                    $method;
                  }
            } @names;
        }

        my %table = (
            qw(
              Sidef::DataTypes::Bool::Bool            Sidef::Types::Bool::Bool
              Sidef::DataTypes::Array::Array          Sidef::Types::Array::Array
              Sidef::DataTypes::Array::Pair           Sidef::Types::Array::Pair
              Sidef::DataTypes::Array::MultiArray     Sidef::Types::Array::MultiArray
              Sidef::DataTypes::Hash::Hash            Sidef::Types::Hash::Hash
              Sidef::DataTypes::Regex::Regex          Sidef::Types::Regex::Regex
              Sidef::DataTypes::String::String        Sidef::Types::String::String
              Sidef::DataTypes::Number::Number        Sidef::Types::Number::Number
              Sidef::DataTypes::Number::Complex       Sidef::Types::Number::Complex
              Sidef::DataTypes::Range::RangeNumber    Sidef::Types::Range::RangeNumber
              Sidef::DataTypes::Range::RangeString    Sidef::Types::Range::RangeString
              Sidef::DataTypes::Glob::Backtick        Sidef::Types::Glob::Backtick
              Sidef::DataTypes::Glob::Socket          Sidef::Types::Glob::Socket
              Sidef::DataTypes::Glob::Pipe            Sidef::Types::Glob::Pipe
              Sidef::DataTypes::Glob::Dir             Sidef::Types::Glob::Dir
              Sidef::DataTypes::Glob::File            Sidef::Types::Glob::File
              )
        );

        my %seen;

        sub dtypes {
            my ($type, @names) = @_;

            exists($table{$type}) || die "[ERROR] Non-existent data type: $type";

            my $package = $table{$type};
            my $module = ($cache{$package} //= (($package =~ s{::}{/}gr) . '.pm'));
            exists($INC{$module}) || require($module);

            if (not $seen{$type}++) {
                no strict 'refs';
                push @{$type . '::' . 'ISA'}, $package;
            }

            map {
                $cache{$type, $_} //= do {
                    defined(my $method = UNIVERSAL::can($type, $_))
                      or die "[ERROR] Invalid method $type: $_";
                    $method;
                  }
            } @names;
        }
    }

    sub table {
        [@_];
    }

    # It's probably easier to use a Cartesian product here,
    # but for our purposes, it's good enough. At least for now.
    sub build_tree {
        my (@data) = @_;

        my %tree;
        foreach my $node (@data) {
            my $ref = ($tree{$node->[0]} //= {});
            $ref = $ref->{$#{$node->[1]}} //= {};
            my $orig = $ref;
            foreach my $arg (@{$node->[1]}) {
                my $ref2 = $ref;
                foreach my $key (@{$arg}) {
                    $ref = $ref2->{$key} //= {};
                }
            }
        }

        \%tree;
    }

    my %rules = (
        (STRING) => build_tree(

            # String.method(String)
            (
             map { [$_, [table(STRING)]] }
               methods(STRING, qw(
                   to
                   downto

                   concat
                   prepend

                   gt lt le ge cmp

                   xor and or
                   eq ne

                   index
                   crypt

                   levenshtein
                   jaro_distance
                   contains
                   overlaps
                   begins_with
                   ends_with
                   count
                   range

                   sprintf
                   sprintlnf

                   encode
                   decode
                   )
               )
            ),

            # String.method()
            (
             map { [$_, []] }
               methods(STRING, qw(
                   lc uc fc tc wc tclc lcfirst

                   pop
                   chop
                   chomp

                   chars_len
                   bytes_len
                   graphs_len

                   pipe
                   chars
                   bytes
                   lines
                   words
                   backtick
                   graphemes

                   ord
                   oct
                   hex
                   bin
                   num
                   not

                   first
                   last

                   repeat
                   reverse
                   clear
                   sort
                   split

                   is_empty
                   is_palindrome

                   trim
                   trim_beg
                   trim_end

                   encode_utf8
                   decode_utf8

                   sprintf
                   sprintlnf

                   dump to_s
                   apply_escapes
                   unescape
                   quotemeta
                   looks_like_number
                   )
               )
            ),

            # String.method(Number)
            (
             map { [$_, [table(NUMBER)]] }
               methods(STRING, qw(
                   eq ne

                   mul
                   div
                   repeat
                   char

                   sprintf
                   sprintlnf

                   shift_left
                   shift_right
                   )
               )
            ),

            # String.method(String | Number | Regex)
            (map { [$_, [table(STRING, NUMBER, REGEX)]] } methods(STRING, qw(split))),

            # String.method(String, String)
            (
             map { [$_, [table(STRING), table(STRING)]] }
               methods(STRING, qw(
                   tr
                   )
               )
            ),

            # String.method(String, String, String)
            (
             map { [$_, [table(STRING), table(STRING), table(STRING)]] }
               methods(STRING, qw(
                   tr
                   )
               )
            ),

            # String.method(String, Number)
            (
             map { [$_, [table(STRING), table(NUMBER)]] }
               methods(STRING, qw(
                   index
                   contains
                   sprintf
                   sprintlnf
                   )
               )
            ),

            # String.method(String, Bool)
            (
             map { [$_, [table(STRING), table(BOOL)]] }
               methods(STRING, qw(
                   range
                   )
               )
            ),

        ),

        (NUMBER) => build_tree(

            # Number.method(Number)
            (
             map { [$_, [table(NUMBER, COMPLEX)]] }
               methods(NUMBER, qw(
                   + - / * % %% **

                   lt gt le ge cmp acmp
                   eq ne
                   and or xor

                   complex
                   root iroot
                   log
                   next_pow
                   max min
                   roundf
                   nok
                   modinv
                   isub
                   iadd
                   imul
                   idiv
                   ipow
                   imod
                   range
                   to xto
                   downto xdownto

                   shift_right
                   shift_left
                   )
               )
            ),

            # Number.method()
            (
             map { [$_, []] }
               methods(NUMBER, qw(
                   inc dec not

                   factorial
                   sqrt isqrt
                   next_pow2
                   abs int

                   exp
                   exp2
                   exp10

                   cos sin

                   ln
                   log
                   log2
                   log10

                   sin
                   asin
                   sinh
                   asinh

                   cos
                   acos
                   cosh
                   acosh

                   tan
                   atan
                   tanh
                   atanh

                   cot
                   acot
                   coth
                   acoth

                   sec
                   sech
                   asec
                   asech

                   csc
                   csch
                   acsc
                   acsch

                   cot
                   acot
                   coth
                   acoth

                   inf
                   neg
                   sign
                   nan
                   chr
                   pi
                   ln2
                   phi
                   tau
                   e
                   Y
                   G

                   is_zero
                   is_one
                   is_nan
                   is_positive
                   is_negative
                   is_even
                   is_odd
                   is_inf
                   is_ninf
                   is_int

                   ceil
                   floor
                   length

                   numerator
                   denominator

                   digits

                   as_bin
                   as_oct
                   as_hex
                   as_rat

                   rat
                   complex i

                   dump
                   commify
                   )
               )
            ),

            # Number.method(Number, Number)
            (
             map { [$_, [table(NUMBER), table(NUMBER)]] }
               methods(NUMBER, qw(
                   modpow
                   range
                   )
               )
            ),
        ),

        (BOOL) => build_tree(
            (
             map { [$_, []] }
               methods(BOOL, qw(
                   not
                   is_true
                   true
                   false
                   to_bool
                   dump
                   )
               )
            ),
        ),

        (ARRAY) => build_tree(
            (
             map { [$_, []] }
               methods(ARRAY, qw(
                   first
                   last

                   len end
                   is_empty
                   min max

                   sum
                   prod

                   sort
                   reverse

                   unique
                   last_unique
                   flatten

                   to_s
                   dump
                   )
               )
            ),

            (
             map { [$_, [table(NUMBER)]] }
               methods(ARRAY, qw(
                   count
                   index
                   rindex
                   exists
                   defined
                   contains
                   contains_type

                   div
                   mul

                   rotate

                   first
                   last
                   item
                   ft

                   sum
                   prod

                   take_right
                   take_left
                   )
               )
            ),

            (
             map { [$_, [table(ARRAY)]] }
               methods(ARRAY, qw(
                   and
                   or
                   xor
                   concat

                   eq ne
                   mzip
                   contains_type
                   contains_any
                   contains_all
                   )
               )
            ),

            (
             map { [$_, [table(STRING)]] }
               methods(ARRAY, qw(
                   pack
                   join
                   index
                   rindex
                   count
                   contains
                   contains_type
                   reduce
                   reduce_operator
                   )
               )
            ),

            (map { [$_, [table('')]] } methods(ARRAY, qw(reduce_operator))),
                             ),

        (COMPLEX) => build_tree(

            # Complex.method(Complex|Number)
            (
             map { [$_, [table(COMPLEX, NUMBER)]] }
               methods(COMPLEX, qw(
                   cmp gt lt ge le eq ne
                   roundf

                   mul
                   div
                   add
                   sub
                   log
                   pow

                   atan2
                   )
               )
            ),

            # Complex.method()
            (
             map { [$_, []] }
               methods(COMPLEX, qw(

                   inc
                   dec
                   abs

                   exp
                   exp2
                   exp10

                   log
                   log2
                   log10
                   sqrt

                   cos
                   sin
                   tan
                   csc
                   sec
                   cot
                   asin
                   acos
                   atan
                   acsc
                   asec
                   acot
                   sinh
                   cosh
                   tanh
                   csch
                   sech
                   coth
                   asinh
                   acosh
                   atanh
                   acsch
                   asech
                   acoth

                   neg
                   not

                   real
                   imaginary

                   is_zero
                   is_one
                   is_nan
                   is_real
                   is_inf
                   is_int

                   ceil
                   floor

                   dump
                   )
               )
            ),
        ),

        (NUMBER_DT) => build_tree(

            # Number.method()
            (
             map { [$_, []] }
               dtypes(NUMBER_DT, qw(
                   pi
                   tau
                   ln2
                   Y
                   G
                   e
                   phi
                   nan
                   inf
                   ninf
                   )
               )
            ),

            # Number.method(STRING|NUMBER)
            (
             map { [$_, [table(STRING, NUMBER)]] }
               dtypes(NUMBER_DT, qw(
                   new
                   )
               )
            ),

            # Number.method(NUMBER, NUMBER)
            (
             map { [$_, [table(NUMBER), table(NUMBER)]] }
               dtypes(NUMBER_DT, qw(
                   new
                   )
               )
            ),

            # Number.method(STRING, NUMBER)
            (
             map { [$_, [table(STRING), table(NUMBER)]] }
               dtypes(NUMBER_DT, qw(
                   new
                   )
               )
            ),
        ),

        (STRING_DT) => build_tree(

            # String.method(STRING|NUMBER)
            (
             map { [$_, [table(STRING, NUMBER)]] }
               dtypes(STRING_DT, qw(
                   new
                   )
               )
            ),
        ),

        (REGEX_DT) => build_tree(

            # Regex.method(STRING)
            (
             map { [$_, [table(STRING)]] }
               dtypes(REGEX_DT, qw(
                   new
                   )
               )
            ),
        ),

        (RANGENUM_DT) => build_tree(

            # RangeNum.method(NUMBER, NUMBER)
            (
             map { [$_, [table(NUMBER), table(NUMBER)]] }
               dtypes(RANGENUM_DT, qw(
                   new
                   )
               )
            ),

            # RangeNum.method(NUMBER, NUMBER)
            (
             map { [$_, [table(NUMBER), table(NUMBER), table(NUMBER)]] }
               dtypes(RANGENUM_DT, qw(
                   new
                   )
               )
            ),
        ),

        (COMPLEX_DT) => build_tree(

            # Complex.method()
            (
             map { [$_, []] }
               dtypes(COMPLEX_DT, qw(
                   i
                   e
                   pi
                   phi
                   new
                   )
               )
            ),

            # Complex.method(STRING|NUMBER)
            (
             map { [$_, [table(STRING, NUMBER)]] }
               dtypes(COMPLEX_DT, qw(
                   new
                   )
               )
            ),

            # Complex.method(NUMBER|STRING, NUMBER|STRING)
            (
             map { [$_, [table(STRING), table(STRING)]] }
               dtypes(COMPLEX_DT, qw(
                   new
                   )
               )
            ),

            (
             map { [$_, [table(STRING), table(NUMBER)]] }
               dtypes(COMPLEX_DT, qw(
                   new
                   )
               )
            ),

            (
             map { [$_, [table(NUMBER), table(STRING)]] }
               dtypes(COMPLEX_DT, qw(
                   new
                   )
               )
            ),

            (
             map { [$_, [table(NUMBER), table(NUMBER)]] }
               dtypes(COMPLEX_DT, qw(
                   new
                   )
               )
            ),
        ),

        (BACKTICK_DT) => build_tree(

            # Backtick.method(STRING)
            (
             map { [$_, [table(STRING)]] }
               dtypes(BACKTICK_DT, qw(
                   new
                   )
               )
            ),
        ),
    );

    my %addr;

    sub new {
        my (undef, %opts) = @_;
        %addr = ();
        bless \%opts, __PACKAGE__;
    }

    sub optimize_expr {
        my ($self, $expr) = @_;

        my $obj = $expr->{self};

        # Self obj
        my $ref = ref($obj);
        if ($ref eq 'HASH') {
            $obj = $self->optimize($obj);
        }
        elsif ($ref eq "Sidef::Variable::Variable") {
            if ($obj->{type} eq 'var') {
                ## ok
            }
            elsif ($obj->{type} eq 'func' or $obj->{type} eq 'method') {
                if ($addr{refaddr($obj)}++) {
                    ## ok
                }
                else {
                    $obj->{value} = $self->optimize_expr({self => $obj->{value}});
                }
            }
        }
        elsif ($ref eq 'Sidef::Variable::Static') {
            if ($addr{refaddr($obj)}++) {
                ## ok
            }
            else {
                my %code = $self->optimize($obj->{expr});
                $obj->{expr} = \%code;
            }
        }
        elsif ($ref eq 'Sidef::Variable::Init') {
            if ($addr{refaddr($obj)}++) {
                ## ok
            }
            else {
                if (exists $obj->{args}) {
                    my %code = $self->optimize($obj->{args});
                    $obj->{args} = \%code;
                }
            }
        }
        elsif (   $ref eq 'Sidef::Variable::ClassInit'
               or $ref eq 'Sidef::Types::Block::Do'
               or $ref eq 'Sidef::Types::Block::Loop'
               or $ref eq 'Sidef::Types::Block::Given'
               or $ref eq 'Sidef::Types::Block::When'
               or $ref eq 'Sidef::Types::Block::Case'
               or $ref eq 'Sidef::Types::Block::Default') {
            if ($addr{refaddr($obj)}++) {
                ## ok
            }
            else {
                my %code = $self->optimize($obj->{block}{code});
                $obj->{block}{code} = \%code;
            }
        }
        elsif ($ref eq 'Sidef::Types::Block::BlockInit') {
            if ($addr{refaddr($obj)}++) {
                ## ok
            }
            else {
                my %code = $self->optimize($obj->{code});
                $obj->{code} = \%code;
            }
        }
        elsif ($ref eq 'Sidef::Types::Array::HCArray') {
            my $has_expr = 0;

            foreach my $i (0 .. $#{$obj}) {
                if (ref($obj->[$i]) eq 'HASH') {
                    $obj->[$i] = $self->optimize_expr($obj->[$i]);
                    $has_expr ||= ref($obj->[$i]) eq 'HASH';
                }
            }

            # Has no expressions, so let's convert it into an Array
            if (not $has_expr) {

                #$obj = Sidef::Types::Array::Array->new(@{$obj});
                bless $obj, 'Sidef::Types::Array::Array';
            }
        }
        elsif ($ref eq 'Sidef::Types::Block::If') {
            foreach my $i (0 .. $#{$obj->{if}}) {
                my %code = $self->optimize($obj->{if}[$i]{block}{code});
                $obj->{if}[$i]{block}{code} = \%code;

                my %expr = $self->optimize($obj->{if}[$i]{expr});
                $obj->{if}[$i]{expr} = \%expr;
            }
            if (exists $obj->{else}) {
                my %code = $self->optimize($obj->{else}{block}{code});
                $obj->{else}{block}{code} = \%code;
            }
        }
        elsif ($ref eq 'Sidef::Types::Block::With') {
            foreach my $i (0 .. $#{$obj->{with}}) {
                my %code = $self->optimize($obj->{with}[$i]{block}{code});
                $obj->{with}[$i]{block}{code} = \%code;

                my %expr = $self->optimize($obj->{with}[$i]{expr});
                $obj->{with}[$i]{expr} = \%expr;
            }
            if (exists $obj->{else}) {
                my %code = $self->optimize($obj->{else}{block}{code});
                $obj->{else}{block}{code} = \%code;
            }
        }
        elsif (   $ref eq 'Sidef::Types::Block::While'
               or $ref eq 'Sidef::Types::Block::ForIn'
               or $ref eq 'Sidef::Types::Block::ForEach') {
            my %expr = $self->optimize($obj->{expr});
            $obj->{expr} = \%expr;

            my %code = $self->optimize($obj->{block}{code});
            $obj->{block}{code} = \%code;
        }
        elsif ($ref eq 'Sidef::Types::Block::CFor') {
            foreach my $i (0 .. $#{$obj->{expr}}) {
                my %expr = $self->optimize($obj->{expr}[$i]);
                $obj->{expr}[$i] = \%expr;
            }
            my %code = $self->optimize($obj->{block}{code});
            $obj->{block}{code} = \%code;
        }
        elsif ($ref eq 'Sidef::Variable::NamedParam') {
            $obj->[1] = [map { {main => [$self->optimize_expr({self => $_})]} } @{$obj->[1]}];
        }

        if (not exists($expr->{ind}) and not exists($expr->{call})) {
            return (ref($obj) eq 'HASH' ? {self => $obj} : $obj);
        }

        $obj = {
                self => $obj,
                (exists($expr->{ind})  ? (ind  => []) : ()),
                (exists($expr->{call}) ? (call => []) : ()),
               };

        # Array and hash indices
        if (exists $expr->{ind}) {
            foreach my $i (0 .. $#{$expr->{ind}}) {
                my $ind = $expr->{ind}[$i];
                if (exists $ind->{array}) {
                    $obj->{ind}[$i]{array} = [map { ref($_) eq 'HASH' ? $self->optimize_expr($_) : $_ } @{$ind->{array}}];
                }
                else {
                    $obj->{ind}[$i]{hash} = [map { ref($_) eq 'HASH' ? $self->optimize_expr($_) : $_ } @{$ind->{hash}}];
                }
            }
        }

        # Method call on the self obj (+optional arguments)
        if (exists $expr->{call}) {

            my $count   = 0;
            my $ref_obj = ref($obj->{self});

            foreach my $i (0 .. $#{$expr->{call}}) {
                my $call = $expr->{call}[$i];

                # Method call
                my $method = $call->{method};

                if (defined $method) {
                    if (ref($method) eq 'HASH') {
                        $method = $self->optimize_expr($method) // {self => {}};
                    }

                    $obj->{call}[$i] = {method => $method};
                }
                elsif (exists $call->{keyword}) {
                    $obj->{call}[$i] = {keyword => $call->{keyword}};
                }

                # Method arguments
                if (exists $call->{arg}) {
                    foreach my $j (0 .. $#{$call->{arg}}) {
                        my $arg = $call->{arg}[$j];
                        push @{$obj->{call}[$i]{arg}},
                            ref($arg) eq 'HASH' ? do { my %arg = $self->optimize($arg); \%arg }
                          : ref($arg) ? $self->optimize_expr({self => $arg})
                          :             $arg;
                    }
                }

                # Block
                if (exists $call->{block}) {
                    foreach my $j (0 .. $#{$call->{block}}) {
                        my $arg = $call->{block}[$j];
                        push @{$obj->{call}[$i]{block}},
                            ref $arg eq 'HASH' ? do { my %arg = $self->optimize($arg); \%arg }
                          : ref($arg) ? $self->optimize_expr({self => $arg})
                          :             $arg;
                    }
                }

                #
                ## Constant folding support
                #
                my $optimized = 0;
                if (    defined($ref_obj)
                    and exists($rules{$ref_obj})
                    and ref($method) eq '') {

                    my $code = ($cache{$ref_obj, $method} //= UNIVERSAL::can($ref_obj, $method));

                    if (defined $code) {
                        my $obj_call = $obj->{call}[$i];

                        my $ref = $rules{$ref_obj};
                        if (exists($ref->{$code}) and (exists($obj_call->{arg}) ? ($#{$obj_call->{arg}} == 0) : 1)) {
                            $ref = $ref->{$code};

                            my @args = (
                                  exists($obj_call->{arg})
                                ? ref($obj_call->{arg}[0]) eq 'HASH'
                                      ? do {
                                          @{(values(%{$obj_call->{arg}[0]}))[0]};
                                      }
                                      : $obj_call->{arg}[0]
                                : ()
                            );

                            if (exists $ref->{$#args}) {
                                $ref = $ref->{$#args};
                                my $ok = 1;
                                foreach my $arg (@args) {
                                    if (exists $ref->{ref($arg)}) {
                                        $ref = $ref->{ref($arg)};
                                    }
                                    else {
                                        $ok = 0;
                                        last;
                                    }
                                }

                                if ($ok) {
                                    $obj->{self} = $obj->{self}->$code(@args);
                                    $ref_obj     = ref($obj->{self});
                                    $optimized   = 1;
                                }
                            }
                        }
                    }
                }

                if ($optimized) {
                    ++$count;
                }
                else {
                    undef $ref_obj;
                }
            }

            if ($count > 0) {
                if ($count == @{$obj->{call}}) {
                    if (not exists $expr->{ind}) {
                        return $obj->{self};
                    }
                    else {
                        delete $obj->{call};
                    }
                }
                else {
                    splice(@{$obj->{call}}, 0, $count);
                }
            }
        }

        return $obj;
    }

    sub optimize {
        my ($self, $struct) = @_;

        my %opt_struct;
        my @classes = keys %{$struct};

        foreach my $class (@classes) {
            foreach my $i (0 .. $#{$struct->{$class}}) {
                push @{$opt_struct{$class}}, scalar $self->optimize_expr($struct->{$class}[$i]);
            }
        }

        wantarray ? %opt_struct : $#{$opt_struct{$classes[-1]}} > 0 ? \%opt_struct : $opt_struct{$classes[-1]}[-1];
    }
};

1;
