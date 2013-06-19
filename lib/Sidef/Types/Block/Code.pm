
use 5.014;
use strict;
use warnings;

package Sidef::Types::Block::Code {

    use parent qw(Sidef);

    require Sidef::Exec;
    my $exec = Sidef::Exec->new();

    sub new {
        my (undef, $code) = @_;
        bless $code, __PACKAGE__;
    }

    {
        no strict 'refs';

        *{__PACKAGE__ . '::' . '||'} = sub {
            my ($self, $code) = @_;

            my $method = '||';
            my @results = $exec->execute(struct => $self);

            return $results[-1]->$method($code);
        };

        *{__PACKAGE__ . '::' . '&&'} = sub {
            my ($self, $code) = @_;

            my $method = '&&';
            my @results = $exec->execute(struct => $self);

            return $results[-1]->$method($code);
        };

        *{__PACKAGE__ . '::' . '?'} = sub {
            my ($self, $code) = @_;

            my $method = '?';
            my @results = $exec->execute(struct => $self);

            return $results[-1]->$method($code);
        };

        *{__PACKAGE__ . '::' . '*'} = sub {
            my ($self, $num) = @_;

            $self->_is_number($num) || return $self;

            foreach my $i (1 .. $num) {
                $exec->execute(struct => $self);
            }

            $self;
        };

        *{__PACKAGE__ . '::' . ':'} = sub {
            my ($self, $code) = @_;

            if (ref($code) eq 'Sidef::Types::Block::Code') {
                return $code->to_hash;
            }

            return $self;
        };
    }

    sub to_hash {
        my ($self) = @_;
        my @results = $exec->execute(struct => $self);
        shift @results;    # ignore the block private variable (_)
        Sidef::Types::Hash::Hash->new(@results);
    }

    sub _run_code {
        my ($self) = @_;
        my $result = $self->run;
            ref($result) eq 'Sidef::Types::Block::Return' ? $result
          : ref($result) eq 'Sidef::Types::Block::Break'  ? $self
          :                                                 ();
    }

    sub run {
        my ($self) = @_;
        my @results = $exec->execute(struct => $self);
        return $results[-1];
    }

    sub exec {
        my ($self) = @_;
        $exec->execute(struct => $self);
        $self;
    }

    *do = \&exec;

    sub while {
        my ($self, $condition) = @_;

        $self->_is_code($condition) || return $self;

        {
            my $bool = $condition->run;
            $self->_is_bool($bool) || return $self;

            if ($bool) {
                my $res = $self->_run_code();
                return $res if defined $res;
                redo;
            }
        }

        $self;
    }

    sub call {
        my ($self, @args) = @_;

        my @results;

        foreach my $class (keys %{$self}) {

            my $argc = 0;
            my @vars = @{$self->{$class}}[1 .. $#args + 1];

            foreach my $var (@vars) {
                if (ref $var->{self} ne 'Sidef::Variable::Ref') {
                    warn "[WARN] Too many arguments in function call!",
                      " Expected $argc, but got ${\(scalar @vars)} of them.\n";
                    last;
                }

                ++$argc;
                my $var_ref = $exec->execute_expr(expr => $var, class => $class);
                $var_ref->get_var->set_value(shift @args);
            }

            push @results, $exec->execute(struct => $self);
        }

        return $results[-1];
    }

    sub if {
        my ($self, $bool) = @_;

        $self->_is_bool($bool) || return Sidef::Types::Bool::Bool->false;

        if ($bool) {
            $self->exec;
        }

        return $bool;
    }

    sub given {
        my ($self) = @_;

        if (ref $self eq 'Sidef::Types::Block::Code') {
            my @results = $exec->execute(struct => $self);
            $self = $results[-1];
        }

        Sidef::Types::Block::Switch->new($self);
    }

    sub for {
        my ($self, $arg) = @_;

        if (ref $arg eq 'Sidef::Types::Array::Array') {
            foreach my $class (keys %{$self}) {
                my $var_ref = $exec->execute_expr(expr => $self->{$class}[0]);
                foreach my $item (@{$arg}) {
                    $var_ref->get_var->set_value($item->get_value);
                    my $res = $self->_run_code();
                    return $res if defined $res;
                }
            }

        }
        elsif (ref $arg eq 'Sidef::Types::Block::Code') {

            my $counter = 0;
            {
                foreach my $class (keys %{$arg}) {

                    if ($counter++ == 0) {

                        if ((my $argn = $#{$arg->{$class}}) != 3) {
                            warn "[WARN] The 'for' loop needs exactly three arguments! We got $argn of them.\n";
                        }

                        $exec->execute_expr(expr => $arg->{$class}[1], class => $class);
                    }

                    my $expr = $arg->{$class}[3];
                    my ($bool) = $exec->execute_expr(expr => $arg->{$class}[2], class => $class);

                    if ($bool->is_true) {
                        my $res = $self->_run_code();
                        return $res if defined $res;
                        $exec->execute_expr(expr => $expr, class => $class);
                        redo;
                    }
                }
            }
        }

        $self;
    }

}

1;
