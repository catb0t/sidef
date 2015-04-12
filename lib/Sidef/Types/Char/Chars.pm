package Sidef::Types::Char::Chars {

    use parent qw(
      Sidef::Types::Array::Array
      );

    sub new {
        my (undef, @chars) = @_;
        bless [@{Sidef::Types::Array::Array->new(@chars)}], __PACKAGE__;
    }

    sub call {
        my ($self, $string) = @_;
        $self->new(map { Sidef::Types::Char::Char->new($_) } split //, $string);
    }

    sub dump {
        my ($self) = @_;
        Sidef::Types::String::String->new('Chars.new(' . join(', ', map { $_->get_value->dump->get_value } @{$self}) . ')');
    }
};

1
