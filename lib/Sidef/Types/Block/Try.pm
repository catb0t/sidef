package Sidef::Types::Block::Try {

    use 5.014;
    our @ISA = qw(Sidef);

    sub new {
        bless {catch => 0}, __PACKAGE__;
    }

    sub try {
        my ($self, $code) = @_;
        $self->_is_code($code) || return;

        my $error = 0;
        local $SIG{__WARN__} = sub { $self->{type} = 'warning'; $self->{msg} = $_[0]; $error = 1 };
        local $SIG{__DIE__}  = sub { $self->{type} = 'error';   $self->{msg} = $_[0]; $error = 1 };

        $self->{val} = eval { $code->run };

        if ($@ || $error) {
            $self->{catch} = 1;
        }

        $self;
    }

    sub catch {
        my ($self, $code) = @_;
        $self->_is_code($code) || return;
        $self->{catch}
          ? do {
            my ($type, $msg) = $code->init_block_vars();
            $type->set_value(Sidef::Types::String::String->new($self->{type}));
            $msg->set_value(Sidef::Types::String::String->new($self->{msg} =~ s/^\[.*?\]\h*//r)->chomp) if defined($msg);
            $code->run;
          }
          : $self->{val};
    }

};

1
