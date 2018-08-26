package Sidef::Types::Set::Set {

    use utf8;
    use 5.014;

    use parent qw(Sidef::Types::Hash::Hash);

    use overload
      q{bool} => sub { scalar(CORE::keys(%{$_[0]})) },
      q{0+}   => sub { scalar(CORE::keys(%{$_[0]})) },
      q{""}   => \&_dump;

    use Sidef::Types::Bool::Bool;
    use Sidef::Types::Number::Number;

    my $serialize = sub {
        my ($obj) = @_;
        my $key = ref($obj) ? (UNIVERSAL::can($obj, 'dump') ? $obj->dump : $obj) : ($obj // 'nil');
        "$key";
    };

    sub new {
        my (undef, @objects) = @_;
        bless {map { $serialize->($_) => $_ } @objects};
    }

    *call = \&new;

    sub get_value {
        my %addr;

        my $sub = sub {
            my ($obj) = @_;

            my $refaddr = Scalar::Util::refaddr($obj);

            exists($addr{$refaddr})
              && return $addr{$refaddr};

            my @set;
            $addr{$refaddr} = \@set;

            foreach my $v (CORE::values(%$obj)) {
                CORE::push(
                           @set,
                           (
                            index(ref($v), 'Sidef::') == 0
                            ? $v->get_value
                            : $v
                           )
                          );
            }

            $addr{$refaddr};
        };

        local *Sidef::Types::Set::Set::get_value = $sub;
        $sub->($_[0]);
    }

    sub length {
        my ($self) = @_;
        Sidef::Types::Number::Number->_set_uint(scalar CORE::keys(%$self));
    }

    *len  = \&length;
    *size = \&length;

    sub concat {
        my ($A, $B) = @_;

        UNIVERSAL::isa($B, 'HASH')
          ? bless({%$A, %$B}, ref($A))
          : bless({%$A, $serialize->($B) => $B}, ref($A));
    }

    sub union {
        my ($A, $B) = @_;

        my %C = %$A;
        foreach my $key (CORE::keys(%$B)) {
            if (!CORE::exists($C{$key})) {
                $C{$key} = $B->{$key};
            }
        }

        bless \%C, ref($A);
    }

    *or = \&union;

    sub intersection {
        my ($A, $B) = @_;

        my %C;

        foreach my $key (CORE::keys(%$A)) {
            if (CORE::exists($B->{$key})) {
                $C{$key} = $A->{$key};
            }
        }

        bless \%C, ref($A);
    }

    *and = \&intersection;

    sub difference {
        my ($A, $B) = @_;

        my %C;

        foreach my $key (CORE::keys(%$A)) {
            if (!CORE::exists($B->{$key})) {
                $C{$key} = $A->{$key};
            }
        }

        bless \%C, ref($A);
    }

    *diff = \&difference;

    sub symmetric_difference {
        my ($A, $B) = @_;

        my %C;

        foreach my $key (CORE::keys(%$A)) {
            if (!CORE::exists($B->{$key})) {
                $C{$key} = $A->{$key};
            }
        }

        foreach my $key (CORE::keys(%$B)) {
            if (!CORE::exists($A->{$key})) {
                $C{$key} = $B->{$key};
            }
        }

        bless \%C, ref($A);
    }

    *xor     = \&symmetric_difference;
    *symdiff = \&symmetric_difference;

    sub append {
        my ($self, @objects) = @_;

        foreach my $obj (@objects) {
            my $key = $serialize->($obj);
            $self->{$key} = $obj;
        }

        $self;
    }

    *add  = \&append;
    *push = \&append;

    sub pop {
        my ($self) = @_;
        CORE::delete(@{$self}{(CORE::keys(%$self))[-1]});
    }

    sub shift {
        my ($self) = @_;
        CORE::delete(@{$self}{(CORE::keys(%$self))[0]});
    }

    sub delete {
        my ($self, @objects) = @_;
        delete @{$self}{map { $serialize->($_) } @objects};
    }

    *remove  = \&delete;
    *discard = \&delete;

    sub map {
        my ($self, $block) = @_;

        my %new;
        foreach my $key (CORE::keys(%$self)) {
            my $value = $block->run($self->{$key});
            $new{$serialize->($value)} = $value;
        }

        bless \%new, ref($self);
    }

    sub collect {
        my ($self, $block) = @_;

        my @array;
        foreach my $value (CORE::values(%$self)) {
            CORE::push(@array, $block->run($value));
        }

        Sidef::Types::Array::Array->new(\@array);
    }

    sub grep {
        my ($self, $block) = @_;

        my %new;
        foreach my $key (CORE::keys(%$self)) {
            my $value = $self->{$key};
            if ($block->run($value)) {
                $new{$key} = $value;
            }
        }

        bless \%new, ref($self);
    }

    *select = \&grep;

    sub count {
        my ($self, $block) = @_;

        my $count = 0;
        foreach my $value (CORE::values(%$self)) {
            if ($block->run($value)) {
                ++$count;
            }
        }

        Sidef::Types::Number::Number->_set_uint($count);
    }

    *count_by = \&count;

    sub delete_if {
        my ($self, $block) = @_;

        foreach my $key (CORE::keys(%$self)) {
            if ($block->run($self->{$key})) {
                CORE::delete($self->{$key});
            }
        }

        $self;
    }

    sub iter {
        my ($self) = @_;

        my $i      = 0;
        my @values = CORE::values(%$self);
        Sidef::Types::Block::Block->new(
            code => sub {
                $values[$i++];
            }
        );
    }

    sub each {
        my ($self, $block) = @_;

        foreach my $value (CORE::values(%$self)) {
            $block->run($value);
        }

        $self;
    }

    sub sort_by {
        my ($self, $block) = @_;
        $self->values->sort_by($block);
    }

    sub sort {
        my ($self, $block) = @_;
        $self->values->sort(defined($block) ? $block : ());
    }

    sub min {
        my ($self) = @_;
        $self->values->min;
    }

    sub max {
        my ($self) = @_;
        $self->values->max;
    }

    sub max_by {
        my ($self, $block) = @_;
        $self->values->max_by($block);
    }

    sub min_by {
        my ($self, $block) = @_;
        $self->values->min_by($block);
    }

    sub has {
        my ($self, $obj) = @_;
        my $key = $serialize->($obj);
        CORE::exists($self->{$key})
          ? (Sidef::Types::Bool::Bool::TRUE)
          : (Sidef::Types::Bool::Bool::FALSE);
    }

    sub is_subset {
        my ($A, $B) = @_;

        foreach my $key (CORE::keys(%$A)) {
            if (!CORE::exists($B->{$key})) {
                return Sidef::Types::Bool::Bool::FALSE;
            }
        }

        return Sidef::Types::Bool::Bool::TRUE;
    }

    *contained_in = \&is_subset;

    sub is_superset {
        my ($A, $B) = @_;

        foreach my $key (CORE::keys(%$B)) {
            if (!CORE::exists($A->{$key})) {
                return Sidef::Types::Bool::Bool::FALSE;
            }
        }

        return Sidef::Types::Bool::Bool::TRUE;
    }

    *include  = \&is_superset;
    *includes = \&is_superset;
    *contain  = \&is_superset;
    *contains = \&is_superset;

    sub contains_all {
        my ($self, @objects) = @_;

        foreach my $obj (@objects) {
            if (!CORE::exists($self->{$serialize->($obj)})) {
                return Sidef::Types::Bool::Bool::FALSE;
            }
        }

        return Sidef::Types::Bool::Bool::TRUE;
    }

    sub to_a {
        my ($self) = @_;
        Sidef::Types::Array::Array->new([CORE::values(%$self)]);
    }

    *values   = \&to_a;
    *to_array = \&to_a;

    sub to_list {
        my ($self) = @_;
        CORE::values(%$self);
    }

    sub _dump {
        my %addr;    # keeps track of dumped objects

        my $sub = sub {
            my ($obj) = @_;

            my $refaddr = Scalar::Util::refaddr($obj);

            exists($addr{$refaddr})
              and return $addr{$refaddr};

            my @values = CORE::values(%$obj);

            $addr{$refaddr} = "Set(#`($refaddr)...)";

            my $s;
            "Set("
              . join(', ', map { (ref($_) && ($s = UNIVERSAL::can($_, 'dump'))) ? $s->($_) : ($_ // 'nil') } @values) . ')';
        };

        local *Sidef::Types::Set::Set::dump = $sub;
        $sub->($_[0]);
    }

    sub dump {
        Sidef::Types::String::String->new($_[0]->_dump);
    }

    {
        no strict 'refs';

        *{__PACKAGE__ . '::' . '+'}   = \&concat;
        *{__PACKAGE__ . '::' . '∪'} = \&union;
        *{__PACKAGE__ . '::' . '|'}   = \&union;
        *{__PACKAGE__ . '::' . '&'}   = \&intersection;
        *{__PACKAGE__ . '::' . '∩'} = \&intersection;
        *{__PACKAGE__ . '::' . '-'}   = \&difference;
        *{__PACKAGE__ . '::' . '∖'} = \&difference;
        *{__PACKAGE__ . '::' . '^'}   = \&symmetric_difference;
        *{__PACKAGE__ . '::' . '<='}  = \&is_subset;
        *{__PACKAGE__ . '::' . '≤'} = \&is_subset;
        *{__PACKAGE__ . '::' . '>='}  = \&is_superset;
        *{__PACKAGE__ . '::' . '≥'} = \&is_superset;
        *{__PACKAGE__ . '::' . '⊆'} = \&is_subset;
        *{__PACKAGE__ . '::' . '⊇'} = \&is_superset;
        *{__PACKAGE__ . '::' . '...'} = \&to_list;
        *{__PACKAGE__ . '::' . '≡'} = \&Sidef::Types::Hash::Hash::eq;
    }
};

1
