
use 5.014;
use strict;
use warnings;

package Sidef::Exec {

    require Sidef::Parser;
    my $parser = Sidef::Parser->new();

    sub new {
        my ($class) = @_;
        bless {}, $class;
    }

    sub interpolate {
        my ($self, %opt) = @_;
        my $self_obj = $opt{self};
        $self_obj->apply_escapes if ref $self_obj eq 'Sidef::Types::String::Double';
    }

    sub eval_array {
        my ($self, %opt) = @_;
        Sidef::Types::Array::Array->new(
            map { Sidef::Variable::Variable->new(rand, 'var', $_) }
              map {
                ref eq 'HASH' ? $self->execute_expr(expr => $_, class => $opt{class}) : $_
              } @{$opt{array}}
        );
    }

    sub execute_expr {
        my ($self, %opt) = @_;

        my $expr = $opt{'expr'};

        if (exists $expr->{self}) {

            my $self_obj = $expr->{self};
            if (ref $self_obj eq 'HASH') {
                ($self_obj) = $self->execute(struct => $self_obj);
            }

            if (ref $self_obj ~~ ['Sidef::Types::Regex::Regex', 'Sidef::Types::String::Double']) {
                $self->interpolate(self => $self_obj, class => $opt{class});
            }

            if (exists $expr->{ind}) {

                if (ref $self_obj eq 'Sidef::Variable::Variable') {
                    $self_obj = $self_obj->get_value;
                }

                    my @ind;
                    foreach my $i (@{$expr->{ind}}) {
                        my $ind = $self->execute_expr(expr => $i, class=>$opt{class});
                        push @ind, $ind;
                        $self_obj->[$ind] //= Sidef::Variable::Variable->new(rand, 'var');
                    }

                     if (@ind > 1) {
                            $self_obj = Sidef::Types::Array::Array->new(@{$self_obj}[@ind]);
                        }
                        else {
                            $self_obj =   $self_obj->[$ind[0]];
                    }
            }

            if (ref $self_obj eq 'Sidef::Types::Array::Array') {
               $self_obj = $self->eval_array(array => $self_obj, class => $opt{class});
            }

            if (exists $expr->{call}) {

                foreach my $call (@{$expr->{call}}) {

                    my @arguments;
                    my $method = $call->{name};

                    if (ref $method eq 'HASH') {
                        $method = $self->execute_expr(expr => $method);
                    }

                    if (ref $self_obj eq 'Sidef::Variable::Variable' and not $$method ~~ ['=', ':=']) {
                        $self_obj = $self_obj->get_value;
                    }

                    if (exists $call->{arg}) {

                        foreach my $arg (@{$call->{arg}}) {
                            if (ref $arg eq 'HASH') {
                                push @arguments, $self->execute(struct => $arg);
                            }
                            else {
                                push @arguments, $arg;
                            }
                        }

                        foreach my $obj (@arguments) {
                            #if (ref $obj ~~ ['Sidef::Types::Regex::Regex', 'Sidef::Types::String::Double']) {
                               # $self->interpolate(self => $obj, class => $opt{class});
                            #}
                            #elsif (ref $obj eq 'Sidef::Types::Array::Array') {
                               # $obj = $self->eval_array(array => $obj, class => $opt{class});
                            #}
                            if (ref $obj eq 'Sidef::Variable::Variable') {
                                $obj = $obj->get_value;
                            }
                        }

                        $self_obj = $self_obj->$method(@arguments);

                        if (ref $self_obj eq 'Sidef::Variable::Variable') {
                            $self_obj = $self_obj->get_value;
                        }

                    }
                    else {
                        if (ref $self_obj eq 'Sidef::Variable::Variable') {
                            $self_obj = $self_obj->get_value;
                        }

                        $self_obj = $self_obj->$method;

                        if (ref $self_obj eq 'Sidef::Variable::Variable') {
                            $self_obj = $self_obj->get_value;
                        }
                    }
                }
            }

            return $self_obj;
        }
        else {
            die "Struct error!\n";
        }
    }

    sub execute {
        my ($self, %opt) = @_;

        my $struct = $opt{'struct'};

        my @results;
        foreach my $key (keys %{$struct}) {
            foreach my $expr (@{$struct->{$key}}) {
                push @results, $self->execute_expr(class => $key, expr => $expr);
            }
        }

        return @results;
    }
};

1;
