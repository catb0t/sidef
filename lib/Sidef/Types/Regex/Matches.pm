package Sidef::Types::Regex::Matches {

    use 5.014;
    use strict;
    use warnings;

    use overload 'bool' => \&to_bool;

    sub new {
        my (undef, %hash) = @_;

        my @matches;
        if ($hash{self}{global}) {
            pos($hash{obj}) = $hash{self}{pos};
            my $match = $hash{obj} =~ /$hash{self}{regex}/g;

            if ($match) {
                $hash{self}{pos} = pos($hash{obj});

                foreach my $i (1 .. $#{+}) {
                    push @matches, substr($hash{obj}, $-[$i], $+[$i] - $-[$i]);
                }

                $hash{matched} = 1;
            }
            else {
                $hash{matched} = 0;
            }

            foreach my $key (keys %+) {
                $hash{named_matches}{$key} = $+{$key};
            }
        }
        else {
            @matches =
              defined($hash{pos})
              ? (substr($hash{obj}, $hash{pos}) =~ $hash{self}{regex})
              : ($hash{obj} =~ $hash{self}{regex});

            $hash{matched} = (@matches != 0);
            $hash{match_pos} = $hash{matched} ? [$-[0] + ($hash{pos} // 0), $+[0] + ($hash{pos} // 0)] : [];

            if (not defined $1) {
                @matches = ();
            }

            foreach my $key (keys %+) {
                $hash{named_matches}{$key} = $+{$key};
            }
        }

        $hash{matches} = \@matches;
        bless \%hash, __PACKAGE__;
    }

    sub matched {
        Sidef::Types::Bool::Bool->new($_[0]->{matched});
    }

    *to_bool       = \&matched;
    *toBool        = \&matched;
    *isSuccessful  = \&matched;
    *is_successful = \&matched;

    sub pos {
        my ($self) = @_;
        Sidef::Types::Array::Array->new(map { Sidef::Types::Number::Number->new($_) } @{$self->{match_pos}});
    }

    sub matches {
        my ($self) = @_;
        Sidef::Types::Array::Array->new(map { Sidef::Types::String::String->new($_) } @{$self->{matches}});
    }

    *captures = \&matches;
    *cap      = \&matches;

    sub named_matches {
        my ($self) = @_;
        my $hash = Sidef::Types::Hash::Hash->new();

        foreach my $key (keys %{$self->{named_matches}}) {
            $hash->{$key} = Sidef::Types::String::String->new($self->{named_matches}{$key});
        }

        $hash;
    }

    *namedMatches   = \&named_matches;
    *namedCaptures  = \&named_matches;
    *named_captures = \&named_matches;

    {
        no strict 'refs';
        *{__PACKAGE__ . '::' . '??'} = \&matched;
    }
}
