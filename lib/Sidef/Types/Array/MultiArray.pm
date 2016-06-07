package Sidef::Types::Array::MultiArray {

    use 5.014;

    use parent qw(
      Sidef::Object::Object
      );

    use overload
      q{""}   => \&dump,
      q{bool} => sub { scalar @{$_[0]} };

    sub new {
        my (undef, @args) = @_;
        my @array = map { [@{$_}] } @args;
        bless \@array, __PACKAGE__;
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

            foreach my $arr (@$obj) {
                my @row;
                foreach my $item (@$arr) {
                    push @row, (index(ref($item), 'Sidef::') == 0 ? $item->get_value : $item);
                }
                push @array, \@row;
            }

            \@array;
        };

        local *Sidef::Types::Array::MultiArray::get_value = $sub;
        $sub->($_[0]);
    }

    sub _max {
        my ($self) = @_;
        state $x = require List::Util;
        List::Util::max(map { $#{$_} } @{$self});
    }

    sub map {
        my ($self, $code) = @_;

        my $max = $self->_max;

        my @arr;
        foreach my $i (0 .. $max) {
            push @arr, scalar $code->run(map { $_->[$i % @{$_}] } @{$self});
        }

        Sidef::Types::Array::Array->new(\@arr);
    }

    sub each {
        my ($self, $code) = @_;

        my $max = $self->_max;

        foreach my $i (0 .. $max) {
            $code->run(map { $_->[$i % @{$_}] } @{$self});
        }

        $self;
    }

    *iter    = \&each;
    *iterate = \&each;

    sub append {
        my ($self, $array) = @_;
        push @{$self}, [@{$array}];
    }

    *push = \&append;

    sub to_array {
        my ($self) = @_;
        Sidef::Types::Array::Array->new([map { Sidef::Types::Array::Array->new(@{$_}) } @{$self}]);
    }

    *to_a = \&to_array;

    sub dump {

        my %addr;    # keeps track of dumped objects

        my $sub = sub {
            my ($obj) = @_;

            my $refaddr = Scalar::Util::refaddr($obj);

            exists($addr{$refaddr})
              and return $addr{$refaddr};

            my $str = Sidef::Types::String::String->new("MultiArr(#`($refaddr)...)");
            $addr{$refaddr} = $str;

            $$str = (
                'MultiArr(' . join(
                    ",\n\t ",
                    map {
                        '['
                          . join(", ", map { ref($_) && defined(UNIVERSAL::can($_, 'dump')) ? $_->dump : $_ } @{$_}) . ']'
                      } @{$obj}
                  )
                  . ")"
            );

            $str;
        };

        local *Sidef::Types::Array::MultiArray::dump = $sub;
        $sub->($_[0]);
    }
};

1
