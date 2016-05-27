package Sidef::Types::Array::Enumerator {

    use 5.014;
    ##use overload q{""} => \&to_a;

    sub new {
        my (undef, $block) = @_;
        bless {block => $block}, __PACKAGE__;
    }

    *call = \&new;

    sub first {
        my ($self, $num) = @_;

        my $n = do {
            local $Sidef::Types::Number::Number::GET_PERL_VALUE = 1;
            $num->get_value;
        };

        my @arr;
        my $count = 0;

        $self->{block}->run(
            Sidef::Types::Block::Block->new(
                code => sub {
                    if (($count += @_) >= $n) {
                        if ($count > $n) {
                            splice(@_, $n - $count);
                        }
                        push @arr, @_;
                        goto RETURN;
                    }
                    push @arr, @_;
                }
            )
        );

      RETURN: Sidef::Types::Array::Array->new(\@arr);
    }

    sub to_a {
        my ($self) = @_;

        my @arr;
        $self->{block}->run(
            Sidef::Types::Block::Block->new(
                code => sub {
                    push @arr, @_;
                },
            )
        );

        Sidef::Types::Array::Array->new(\@arr);
    }

    sub each {
        my ($self, $block) = @_;

        $self->{block}->run(
            Sidef::Types::Block::Block->new(
                code => sub {
                    @_
                      ? @_ == 1
                          ? $block->run($_[0])
                          : do { $block->run($_) for @_ }
                      : ();
                },
            )
        );

        $self;
    }

    sub map {
        my ($self, $block) = @_;

        my @arr;
        $self->{block}->run(
            Sidef::Types::Block::Block->new(
                code => sub {
                    push @arr, map { $block->run($_) } @_;
                },
            )
        );

        Sidef::Types::Array::Array->new(\@arr);
    }

    sub grep {
        my ($self, $block) = @_;

        my @arr;
        $self->{block}->run(
            Sidef::Types::Block::Block->new(
                code => sub {
                    push @arr, grep { $block->run($_) } @_;
                },
            )
        );

        Sidef::Types::Array::Array->new(\@arr);
    }

    *select = \&grep;

    sub length {
        my ($self) = @_;

        my $count = 0;
        $self->{block}->run(
            Sidef::Types::Block::Block->new(
                code => sub {
                    $count += @_;
                },
            )
        );

        Sidef::Types::Number::Number::_new_uint($count);
    }

    *len  = \&length;    # alias
    *size = \&length;

    #
    ## AUTOLOAD
    #

    sub DESTROY { }

    our $AUTOLOAD;

    sub AUTOLOAD {
        my ($self, @arg) = @_;
        my ($method) = ($AUTOLOAD =~ /^.*[^:]::(.*)$/);
        $self->to_a->$method(@arg);
    }
};

1
