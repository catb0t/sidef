package Sidef::Time::Time {

    use 5.014;
    use parent qw(Sidef::Object::Object);

    use overload
      q{""}   => \&get_value,
      q{bool} => \&get_value,
      q{0+}   => \&get_value;

    sub new {
        my (undef, $sec) = @_;

        if (defined $sec) {
            if (ref($sec)) {
                $sec = CORE::int($sec);
            }
        }
        else {
            $sec = time;
        }

        bless \$sec, __PACKAGE__;
    }

    *call = \&new;

    sub get_value {
        ${$_[0]} // CORE::time;
    }

    sub time {
        my ($self) = @_;
        Sidef::Types::Number::Number->new($self->get_value);
    }

    *sec = \&time;

    sub now {
        Sidef::Types::Number::Number->new(CORE::time);
    }

    sub micro {
        my ($self) = @_;
        state $x = require Time::HiRes;
        Sidef::Types::Number::Number->new(scalar Time::HiRes::gettimeofday());
    }

    *micro_sec     = \&micro;
    *micro_seconds = \&micro;

    sub localtime {
        my ($self) = @_;
        Sidef::Time::Localtime->new($self->get_value);
    }

    *local = \&localtime;

    sub gmtime {
        my ($self) = @_;
        Sidef::Time::Gmtime->new($self->get_value);
    }

    sub dump {
        my ($self) = @_;
        Sidef::Types::String::String->new('Time(' . $self->get_value . ')');
    }

    sub to_str {
        my ($self) = @_;
        Sidef::Types::String::String->new($self->get_value);
    }

    *to_s = \&to_str;

};

1;
