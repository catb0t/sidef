package Sidef::Time::Localtime {

    use 5.016;
    use parent qw(
      Sidef::Time::Gmtime
      );

    use overload
      q{""}   => \&ctime,
      q{bool} => sub { $_[0]->{sec} };

    use Sidef::Types::Number::Number;

    sub new {
        my (undef, $sec) = @_;

        bless {
               sec  => $sec,
               time => Sidef::Types::Array::Array->new([map { Sidef::Types::Number::Number->_set_uint($_) } localtime($sec)]),
              },
          __PACKAGE__;
    }

    {
        no strict 'refs';

        # The order matters!
        my @names = qw(sec min hour mday mon year wday yday isdst);

        foreach my $i (0 .. $#names) {
            *{__PACKAGE__ . '::' . $names[$i]} = sub {
                $_[0]{time}[$i];
            };
        }

        *day       = \&mday;
        *month     = \&mon;
        *minute    = \&min;
        *second    = \&sec;
        *month_day = \&mday;
        *week_day  = \&wday;
        *year_day  = \&yday;
    }

    sub ctime {
        my ($self) = @_;
        Sidef::Types::String::String->new(scalar localtime($self->{sec}));
    }

    *to_s   = \&ctime;
    *to_str = \&ctime;
};

1;
