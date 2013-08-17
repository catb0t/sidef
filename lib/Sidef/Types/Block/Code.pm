package Sidef::Types::Block::Code {

    use 5.014;
    use strict;
    use warnings;

    no warnings 'recursion';

    our @ISA = qw(Sidef);

    require Sidef::Exec;
    my $exec = Sidef::Exec->new();

    sub new {
        my (undef, $code) = @_;
        bless $code, __PACKAGE__;
    }

    {
        no strict 'refs';

        *{__PACKAGE__ . '::' . '*'} = \&repeat;

        *{__PACKAGE__ . '::' . ':'} = sub {
            my ($self, $code) = @_;

            if (ref($code) eq 'HASH') {
                return Sidef::Types::Hash::Hash->new($exec->execute(struct => $code));
            }

            warn "[WARN] Missing argument for hash operator ':'!\n";
            return;
        };
    }

    sub repeat {
        my ($self, $num) = @_;

        $num //= Sidef::Types::Number::Number->new(1);
        $self->_is_number($num) || return $self;

        foreach my $i (1 .. $num) {

            my ($var_ref) = $self->_get_private_var();
            $var_ref->get_var->set_value(Sidef::Types::Number::Number->new($i));

            my $res = $self->_run_code();
            return $res if defined $res;
        }

        $self;
    }

    sub to_hash {
        my ($self) = @_;
        my @results = $exec->execute(struct => $self);
        shift @results;    # ignore the block private variable (_)
        Sidef::Types::Hash::Hash->new(@results);
    }

    *toHash = \&to_hash;

    sub to_array {
        my ($self) = @_;
        my @results = $exec->execute(struct => $self);
        shift @results;    # ignore the block private variable (_)
        Sidef::Types::Array::Array->new(@results);
    }

    *toArray = \&to_array;

    sub _run_code {
        my ($self) = @_;
        my $result = $self->run;
            ref($result) eq 'Sidef::Types::Block::Return' ? $result
          : ref($result) eq 'Sidef::Types::Block::Break'  ? $self
          :                                                 ();
    }

    sub _get_private_var {
        my ($self) = @_;

        my ($class) = keys %{$self};
        $exec->execute_expr(expr => $self->{$class}[0], class => $class), $class;
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

        {
            my $bool = Sidef::Types::Block::Code->new($condition)->run;
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
            my @vars = @{$self->{$class}}[1 .. @args * 2];

            my ($var_ref) = $self->_get_private_var();
            $var_ref->get_var->set_value(Sidef::Types::Array::Array->new(@args));

            my $i       = 0;
            my $j       = 1;
            my @express = @{$self->{$class}};
            while (    ref($vars[$i]{self}) eq 'Sidef::Variable::InitMy'
                   and ref($vars[$i + 1]{self}) eq 'Sidef::Variable::Ref') {
                splice(
                       @express,
                       ++$j,
                       0,
                       {
                        self => Sidef::Variable::My->new($vars[$i]{self}->get_name),
                        call => [
                                 {
                                  name => '=',
                                  arg  => [shift @args],
                                 }
                                ]
                       }
                      );
                $j += 2;
                $i += 2;
            }

            #if ($i < $#vars) {
            #    warn "[WARN] Too many arguments in function call!",
            #      " Expected ${\($i/2)}, but got ${\(scalar(@vars)/2)} of them.\n";
            #}

            push @results, $exec->execute(struct => {$class => \@express});
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
        Sidef::Types::Block::Switch->new($self->run);
    }

    sub for {
        my ($self, $arg) = @_;

        if ($self->_is_array($arg, 1, 1)) {
            my ($var_ref) = $self->_get_private_var();

            foreach my $item (@{$arg}) {
                $var_ref->get_var->set_value($item->get_value);
                my $res = $self->_run_code();
                return $res if defined $res;
            }
        }
        elsif (ref $arg eq 'HASH') {

            my $counter = 0;
            {
                foreach my $class (keys %{$arg}) {

                    if ($counter++ == 0) {

                        if ((my $argn = @{$arg->{$class}}) != 3) {
                            warn "[WARN] The 'for' loop needs exactly three arguments! We got $argn of them.\n";
                        }

                        $exec->execute_expr(expr => $arg->{$class}[0], class => $class);
                    }

                    my $expr = $arg->{$class}[2];
                    my ($bool) = $exec->execute_expr(expr => $arg->{$class}[1], class => $class);

                    if ($bool) {
                        my $res = $self->_run_code();
                        return $res if defined $res;
                        $exec->execute_expr(expr => $expr, class => $class);
                        redo;
                    }

                    last;
                }
            }
        }
        else {
            warn sprintf("[WARN] The 'for' loop expected (;;) or [], but got '%s'!\n", ref($arg));
        }

        $self;
    }

}
