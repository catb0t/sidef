
use 5.014;
use strict;
use warnings;

package Sidef::Types::String::Double {

    use parent qw(Sidef::Types::String::String);

    sub new {
        my ($class, $str) = @_;
        bless \$str, $class;
    }

    sub apply_escapes {
        my ($self) = @_;

        state $esc = {
                      n => "\n",
                      f => "\f",
                      b => "\b",
                      e => "\e",
                      r => "\r",
                      t => "\t",
                     };

        {
            local $" = q{};
            ${$self} =~ s{(?<!\\)(?:\\\\)*+\K\\([@{[keys %{$esc}]}])}{$esc->{$1}}go;
            ${$self} =~ s{(?<!\\)(?:\\\\)*+\K\\([LU])((?>[^\\]+|\\[^E])*)(\\E|\z)}{

                $1 eq 'L' ? lc($2) : uc($2);

            }eg;

            ${$self} =~ s{(?<!\\)(?:\\\\)*+\K\\([lu])(.)}{

                $1 eq 'l' ? lc($2) : uc($2);

            }egs;

            ${$self} =~ s{\\(.)}{$1}gs;
        }

        return $self;
    }

}

1;
