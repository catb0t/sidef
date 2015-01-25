package Sidef::Sys::Sys {

    use 5.014;
    our @ISA = qw(Sidef);

    sub new {
        my (undef, %opt) = @_;
        CORE::bless \%opt, __PACKAGE__;
    }

    sub exit {
        my ($self, $code) = @_;
        exit($code // 0);
    }

    sub alarm {
        my ($self, $sec) = @_;

        $self->_is_number($sec) || return;

        require Time::HiRes;
        Sidef::Types::Bool::Bool->new(Time::HiRes::alarm($$sec));
    }

    sub ualarm {
        my ($self, $sec) = @_;

        $self->_is_number($sec) || return;

        require Time::HiRes;
        Sidef::Types::Bool::Bool->new(Time::HiRes::ualarm($$sec));
    }

    sub sleep {
        my ($self, $sec) = @_;

        $self->_is_number($sec) || return;

        require Time::HiRes;
        Sidef::Types::Bool::Bool->new(Time::HiRes::sleep($$sec));
    }

    sub nanosleep {
        my ($self, $sec) = @_;

        $self->_is_number($sec) || return;

        require Time::HiRes;
        Sidef::Types::Bool::Bool->new(Time::HiRes::nanosleep($$sec));
    }

    *nanoSleep = \&nanosleep;

    sub usleep {
        my ($self, $sec) = @_;

        $self->_is_number($sec) || return;

        require Time::HiRes;
        Sidef::Types::Bool::Bool->new(Time::HiRes::usleep($$sec));
    }

    sub osname {
        my ($self) = @_;
        Sidef::Types::String::String->new($^O);
    }

    *osName = \&osname;

    sub user {
        my ($self) = @_;
        Sidef::Types::String::String->new(getlogin);
    }

    sub umask {
        my ($self, $mode) = @_;

        if (defined($mode)) {
            $self->_is_number($mode) || return;
            return Sidef::Types::Number::Number->new(CORE::umask($$mode));
        }

        Sidef::Types::Number::Number->new(CORE::umask);
    }

    sub ref {
        my ($self, $obj) = @_;
        Sidef::Types::String::String->new(CORE::ref $obj);
    }

    sub sidef {
        my ($self) = @_;

        require File::Spec;
        Sidef::Types::String::String->new(File::Spec->rel2abs($0));
    }

    sub die {
        my ($self, @args) = @_;
        if (exists $self->{file_name}) {
            CORE::die(@args, " at $self->{file_name} line $self->{line}.\n");
        }
        else {
            CORE::die(@args, "\n");
        }
    }

    *raise = \&die;

    sub warn {
        my ($self, @args) = @_;
        if (exists $self->{file_name}) {
            CORE::warn(@args, " at $self->{file_name} line $self->{line}.\n");
        }
        else {
            CORE::warn(@args, "\n");
        }
    }

    sub print {
        my ($self, @args) = @_;
        Sidef::Types::Bool::Bool->new(print @args);
    }

    sub printf {
        my ($self, @args) = @_;
        Sidef::Types::Bool::Bool->new(printf @args);
    }

    sub printh {
        my ($self, $fh, @args) = @_;

        if (CORE::ref($fh) eq 'GLOB') {
            return Sidef::Types::Bool::Bool->new(print {$fh} @args);
        }
        elsif (eval { $fh->can('print') || $fh->can('AUTOLOAD') }) {
            return $fh->print(@args);
        }

        CORE::warn "[WARN] Sys.printh(): invalid object handle: `$fh'\n";
        return;
    }

    sub println {
        my ($self, @args) = @_;
        Sidef::Types::Bool::Bool->new(CORE::say @args);
    }

    *say = \&println;

    sub scanln {
        my ($self, $text) = @_;

        if (defined($text)) {
            $self->_is_string($text) || return;
            $text->print;
        }

        Sidef::Types::String::String->new(scalar unpack("A*", scalar <STDIN>));
    }

    *readln = \&scanln;

    sub read {
        my ($self, $type, @vars) = @_;

        if (@vars) {
            foreach my $var_ref (@vars) {
                $self->_is_var_ref($var_ref) || return;
                my $var = $var_ref->get_var;
                print "$var->{name}: ";
                chomp(my $input = <STDIN>);
                $var->set_value($type->new($input));
            }

            return $self;
        }

        if (defined $type) {
            chomp(my $input = <STDIN>);
            return $type->new($input);
        }

        chomp(my $input = <STDIN>);
        Sidef::Types::String::String->new($input);
    }

    sub open {
        my ($self, $var, $mode, $filename) = @_;
        $filename->to_file->open($mode, $var);
    }

    sub opendir {
        my ($self, $var, $dirname) = @_;
        $dirname->to_dir->open($var);
    }

    sub eval {
        my ($self, @args) = @_;
        Sidef::Perl::Perl->eval(@args);
    }

    sub bless {
        my ($self, $obj, $class) = @_;
        CORE::bless $obj, $class;
    }

    sub select {
        my ($self, $fh) = @_;
        CORE::select(CORE::ref($fh) eq 'GLOB' ? $fh : $fh->get_value);
    }

    sub system {
        my ($self, @args) = @_;
        Sidef::Types::Number::Number->new(CORE::system(@args));
    }

    *run = \&system;

    sub exec {
        my ($self, @args) = @_;
        CORE::exec(@args);
    }

    {
        no strict 'refs';
        *{__PACKAGE__ . '::' . '>'}  = \&println;
        *{__PACKAGE__ . '::' . '>>'} = \&print;
    }

};

1
