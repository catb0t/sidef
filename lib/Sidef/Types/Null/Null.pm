package Sidef::Types::Null::Null {

    use utf8;
    use 5.014;

    use overload
      q{bool} => sub { },
      q{0+}   => sub { 0 },
      q{""}   => sub { '' };

    use parent qw(Sidef::Object::Object);

    sub new {
        bless \(my $nil = undef), __PACKAGE__;
    }

    *call = \&new;

    sub get_value {
        undef;
    }

    sub dump {
        Sidef::Types::String::String->new('null');
    }

    *to_s   = \&dump;
    *to_str = \&dump;
};

1
