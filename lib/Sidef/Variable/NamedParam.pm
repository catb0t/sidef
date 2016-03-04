package Sidef::Variable::NamedParam {

    use 5.014;
    use overload q{""} => \&dump;

    sub new {
        my (undef, $name, @args) = @_;
        bless [$name, \@args], __PACKAGE__;
    }

    sub get_value {
        my ($self) = @_;
        map { $_->get_value } @{$self->[1]};
    }

    sub dump {
        my ($self) = @_;
        my ($name, $args) = @{$self};
        my @args = map {
            ref($_) && eval { $_->can('dump') }
              ? $_->dump
              : $_
        } @{$args};
        Sidef::Types::String::String->new("$name: " . (@args == 1 ? $args[0] : ('(' . join(', ', @args) . ')')));
    }
}

1;
