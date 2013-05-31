
use 5.014;
use strict;
use warnings;

package Sidef::Types::Array::Array {

    use parent qw(Sidef::Convert::Convert);

    sub new {
        my ($class, @items) = @_;
        bless [map { Sidef::Variable::Variable->new(rand, 'var', $_) } @items], $class;
    }

    sub _is_array {
        my ($self, $obj) = @_;

        if (not defined $obj->can('_is_array')) {
            warn "[WARN] Expected an array object, but got '", ref($obj), "'.\n";
            return;
        }

        return 1;
    }

    sub _grep {
        my ($self, $array, $bool) = @_;
        my $new_array = ref($self)->new();

        $self->_is_array($array) || return ($self);

        foreach my $item (@{$self}) {

            my $exists = 0;
            my $value  = $item->get_value;

            if ($array->contains($value)) {
                $exists = 1;
            }

            $new_array->push($value) if ($exists - $bool);
        }

        $new_array;
    }

    {
        no strict 'refs';
        *{__PACKAGE__ . '::' . '-'} = sub {
            my ($self, $array) = @_;
            $self->_grep($array, 1);
        };

        *{__PACKAGE__ . '::' . '&'} = sub {
            my ($self, $array) = @_;
            $self->_grep($array, 0);
        };

        *{__PACKAGE__ . '::' . '|'} = sub {
            my ($self, $array) = @_;
            my $new_array = ref($self)->new;

            $self->_is_array($array) || return;

            my $add = '+';
            my $xor = '^';
            my $and = '&';
            $self->$xor($array)->$add($self->$and($array));
        };

        *{__PACKAGE__ . '::' . '^'} = sub {
            my ($self, $array) = @_;
            my $new_array = ref($self)->new;

            $self->_is_array($array) || return;

            my $add    = '+';
            my $and    = '&';
            my $substr = '-';
            ($self->$add($array))->$substr($self->$and($array));
        };

        *{__PACKAGE__ . '::' . '+'} = sub {
            my ($self, $array) = @_;

            $self->_is_array($array) || return ($self);
            __PACKAGE__->new(map { $_->get_value } @{$self}, @{$array});
        };

        *{__PACKAGE__ . '::' . '++'} = sub {
            my ($self, $obj) = @_;
            $self->push($obj);
            $self;
        };

        *{__PACKAGE__ . '::' . '--'} = sub {
            my ($self) = @_;
            $self->pop;
            $self;
        };

        *{__PACKAGE__ . '::' . '&&'} = sub {
            my ($self, $array) = @_;

            $self->_is_array($array) || return ($self);

            my $min = $#{$self} > $#{$array} ? $#{$array} : $#{$self};

            my $new_array = ref($self)->new();
            foreach my $i (0 .. $min) {
                $new_array->push($self->[$i]->get_value, $array->[$i]->get_value);
            }

            if ($#{$self} > $#{$array}) {
                foreach my $i ($min + 1 .. $#{$self}) {
                    $new_array->push($self->[$i]->get_value);
                }
            }
            else {
                foreach my $i ($min + 1 .. $#{$array}) {
                    $new_array->push($array->[$i]->get_value);
                }
            }

            $new_array;
        };

        *{__PACKAGE__ . '::' . '=='} = sub {
            my ($self, $array) = @_;

            $self->_is_array($array) || return ($self);

            if ($#{$self} != $#{$array}) {
                return Sidef::Types::Bool::Bool->false;
            }

            foreach my $i (0 .. $#{$self}) {

                my ($x, $y) = ($self->[$i]->get_value, $array->[$i]->get_value);

                if (ref($x) eq ref($y)) {
                    my $method = '==';

                    if (defined $x->can($method)) {
                        if (not $x->$method($y)) {
                            return Sidef::Types::Bool::Bool->false;
                        }
                    }

                }
                else {
                    return Sidef::Types::Bool::Bool->false;
                }
            }

            return Sidef::Types::Bool::Bool->true;
        };

        *{__PACKAGE__ . '::' . '='} = sub {
            my ($self, $arg) = @_;

            if (ref $arg eq 'Sidef::Types::Array::Array') {
                foreach my $i (0 .. $#{$self}) {
                    $arg->[$i] //= Sidef::Variable::Variable->new(rand, 'var', Sidef::Types::Nil::Nil->new);
                    $self->[$i]->set_value($arg->[$i]->get_value);
                }
            }
            else {
                map { $_->set_value($arg) } @{$self};
            }

            $self;
        };

    }

    sub max {
        my ($self) = @_;

        my $method   = '>';
        my $max_item = $self->[0]->get_value;

        foreach my $i (1 .. $#{$self}) {
            my $val = $self->[$i]->get_value;

            if (defined $val->can($method)) {
                $max_item = $val if $val->$method($max_item);
            }
            else {
                warn "[WARN] Can't find the method '$method' for object '", ref($self->[$i]->get_value), "'!\n";
            }
        }

        return $max_item;
    }

    sub map {
        my ($self, $code) = @_;

        my $exec = Sidef::Exec->new();
        my $variable = $exec->execute_expr(expr => $code->{main}[0], class => 'main');

        ref($self)->new(
            map {
                $variable->alias($_);
                my $val = $_->get_value;
                $variable->set_value(ref $val eq 'Sidef::Variable::Variable' ? $val->get_value : $val);
                my @results = $exec->execute(struct => $code);
                $results[-1];
              } @{$self}
        );
    }

    sub length {
        my ($self) = @_;
        Sidef::Types::Number::Number->new(scalar @{$self});
    }

    *len = \&length;    # alias

    sub insert {
        my ($self, $index, @objects) = @_;
        splice(@{$self}, $index->_get_number, 0, @{__PACKAGE__->new(@objects)});
        $self;
    }

    sub contains {
        my ($self, $obj) = @_;

        foreach my $var (@{$self}) {

            my $item = $var->get_value;
            if (ref($item) eq ref($obj)) {
                my $method = '==';
                if (defined $item->can($method)) {
                    if ($item->$method($obj)) {
                        return Sidef::Types::Bool::Bool->true;
                    }
                }
            }
        }

        Sidef::Types::Bool::Bool->false;
    }

    sub pop {
        my ($self) = @_;
        pop @{$self};
    }

    sub shift {
        my ($self) = @_;
        shift @{$self};
    }

    sub push {
        my ($self, @args) = @_;
        push @{$self}, @{__PACKAGE__->new(@args)};
        return $self;
    }

    sub unshift {
        my ($self, @args) = @_;
        unshift @{$self}, @{__PACKAGE__->new(@args)};
        return $self;
    }

    sub join {
        my ($self, $separator) = @_;
        Sidef::Types::String::String->new(CORE::join($separator->_get_string, @{$self}));
    }

    sub reverse {
        my ($self) = @_;
        ref($self)->new(reverse map { $_->get_value } @{$self});
    }

}

1;
