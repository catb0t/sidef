package Sidef::Types::Block::Do {

    sub new {
        bless {}, __PACKAGE__;
    }

    sub do {
        my ($self, $code) = @_;

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
            return Sidef::Types::Black::Hole->new($result);
        }

        $self;
    }

    *then = \&do;
    *{__PACKAGE__ . '::' . ':'} = \&do;
};

1
