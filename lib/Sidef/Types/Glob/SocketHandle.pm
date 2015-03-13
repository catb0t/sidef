package Sidef::Types::Glob::SocketHandle {

    use 5.014;
    use parent qw(
      Sidef::Types::Glob::FileHandle
      );

    sub new {
        my (undef, %opt) = @_;
        bless \%opt, __PACKAGE__;
    }

    sub setsockopt {
        my ($self, $level, $optname, $optval) = @_;
        Sidef::Types::Bool::Bool->new(
                                    CORE::setsockopt($self->{fh}, $level->get_value, $optname->get_value, $optval->get_value));
    }

    sub getsockopt {
        my ($self, $level, $optname) = @_;
        Sidef::Types::String::String->new(CORE::getsockopt($self->{fh}, $level->get_value, $optname->get_value) // return);
    }

    sub getpeername {
        my ($self) = @_;
        Sidef::Types::String::String->new(CORE::getpeername($self->{fh}) // return);
    }

    sub getsockname {
        my ($self) = @_;
        Sidef::Types::String::String->new(CORE::getsockname($self->{fh}));
    }

    sub bind {
        my ($self, $name) = @_;
        Sidef::Types::Bool::Bool->new(CORE::bind($self->{fh}, $name->get_value));
    }

    sub listen {
        my ($self, $queuesize) = @_;
        Sidef::Types::Bool::Bool->new(CORE::listen($self->{fh}, $queuesize->get_value));
    }

    sub accept {
        my ($self, @args) = @_;
        CORE::accept(my $fh, $self->{fh}) || return;
        Sidef::Types::Glob::SocketHandle->new(fh => $fh);
    }

    sub connect {
        my ($self, $name) = @_;
        Sidef::Types::Bool::Bool->new(CORE::connect($self->{fh}, $name->get_value));
    }

    sub recv {
        my ($self, $length, $flags) = @_;
        CORE::recv($self->{fh}, (my $content), $length->get_value, $flags->get_value) // return;
        Sidef::Types::String::String->new($content);
    }

    sub send {
        my ($self, $msg, $flags, $to) = @_;
        CORE::send($self->{fh}, $msg->get_value, $flags->get_value, defined($to) ? $to->get_value : ());
    }

    sub shutdown {
        my ($self, $how) = @_;
        Sidef::Types::Bool::Bool->new(CORE::shutdown($self->{fh}, $how->get_value));
    }

};

1
