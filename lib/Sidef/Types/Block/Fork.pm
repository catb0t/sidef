package Sidef::Types::Block::Fork {

    use 5.014;

    sub new {
        my (undef, %opts) = @_;
        bless \%opts, __PACKAGE__;
    }

    sub get {
        my ($self) = @_;

        # Wait for the process to finish
        waitpid($self->{pid}, 0);

        # Return when the fork doesn't hold a file-handle
        exists($self->{fh}) or return;

        # Rewind at the beginning
        seek($self->{fh}, 0, 0);

        # Get the content
        my $content = do {
            local $/;
            readline($self->{fh});
        };

        # Evaluate the result
        my $result = eval($content);
        $@ && die "[FORK ERROR] can't retrieve value: $@";
        $result;
    }

    *wait = \&get;
    *join = \&get;

    sub kill {
        my ($self, $signal) = @_;
        kill(defined($signal) ? $signal->get_value : 'KILL', $self->{pid});
    }
};

1
