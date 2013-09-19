package Sidef::Types::Block::Do {

    use 5.014;
    use strict;
    use warnings;

    no warnings 'recursion';

    our @ISA = qw(Sidef);

    sub new {
        bless {}, __PACKAGE__;
    }

    sub do {
        my ($self, $code) = @_;

        $self->_is_code($code) || return;

        if ($self->{do_block}) {
            my $result = $code->run;
            my $ref    = ref($result);
            if ($ref eq 'Sidef::Types::Block::Continue') {
                $self->{do_block} = 0;
                return $self;
            }
            elsif (   $ref eq 'Sidef::Types::Block::Break'
                   or $ref eq 'Sidef::Types::Block::Return'
                   or $ref eq 'Sidef::Types::Block::Next') {
                $self->{do_block} = 0;
                return $result;
            }
            return Sidef::Types::Black::Hole->new();
        }

        $self;
    }

    {
        no strict 'refs';
        *{__PACKAGE__ . '::' . ':'} = \&do;
    }

}
