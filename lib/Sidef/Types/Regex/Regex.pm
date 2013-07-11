package Sidef::Types::Regex::Regex {

    use 5.014;
    use strict;
    use warnings;

    our @ISA = qw(Sidef::Convert::Convert);

    sub new {
        my (undef, $regex, $mod) = @_;

        $mod //= q{^};
        my $str_re = qr{(?$mod:$regex)};

        bless \$str_re, __PACKAGE__;
    }

    sub matches {
        my ($self, $object) = @_;

        if (ref $object eq 'Sidef::Types::Array::Array') {
            foreach my $item (@{$object}) {
                my $match = $self->matches($item);
                $match->matched && return $match;
            }
        }

        Sidef::Types::Regex::Matches->new(obj => $object, regex => $$self);
    }

    {
        no strict 'refs';
        *{__PACKAGE__ . '::' . '=~'} = \&matches;    # alias to the 'matches' method
    }

    sub dump {
        my ($self) = @_;
        Sidef::Types::String::String->new('/' . $$self =~ s{/}{\\/}gr . '/');
    }
}
