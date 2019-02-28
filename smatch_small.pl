
use lib ("\/home\/cat\/Sync\/projects\/git\/sidef\/bin\/\.\.\/lib");

use Sidef;

binmode( STDIN,  ':utf8' );
binmode( STDOUT, ':utf8' );
binmode( STDERR, ':utf8' ) if $^P == 0;

package Sidef::Runtime {
    use utf8;
    use 5.026;

    use constant {
        String942522499455921 => Sidef::Types::String::String->new("asd"), };
    my $new94252246903752;
    my $t94252249373888;
    use Sidef::Types::String::String;
    use Sidef::Types::Number::Number;
    do {

        package Sidef::Runtime::94252246381296::main::Str1 {
            use parent qw(-norequire  Sidef::Object::Object);
            $new94252246903752 = Sidef::Types::Block::Block->new(
                code => sub {
                    my $self = bless {}, __PACKAGE__;
                    if ( defined( my $sub = UNIVERSAL::can( $self, "init" ) ) )
                    {
                        $sub->($self);
                    }
                    $self;
                },
                vars  => [],
                table => {},
                type  => "class",
                name  => "Sidef\:\:Runtime\:\:94252246381296\:\:main\:\:Str1"
            );
            state $_94252246903752= do {
                no strict 'refs';
                *{"Sidef\:\:Runtime\:\:94252246381296\:\:main\:\:Str1\:\:new"}
                  = *{
                    "Sidef\:\:Runtime\:\:94252246381296\:\:main\:\:Str1\:\:call"
                  } =
                  sub { CORE::shift(@_); $new94252246903752->call(@_) }
            };
        };
        'Sidef::Runtime::94252246381296::main::Str1';
    };
    do {

        package Sidef::Runtime::94252248411112::main::S94252248411112 {
            use parent
              qw(-norequire Sidef::Types::String::String Sidef::Types::Number::Number);
        };
        'Sidef::Runtime::94252248411112::main::S94252248411112';
    };
    (
        (
            CORE::say(
                ( (Sidef::Runtime::String942522499455921) )
                ->is_a('Sidef::Runtime::94252248411112::main::S94252248411112')
            )
        ) ? Sidef::Types::Bool::Bool::TRUE : Sidef::Types::Bool::Bool::FALSE
    );
    (
        (
            CORE::say(
                ( @{${ref('Sidef::Runtime::94252248411112::main::S94252248411112') . '::'}{ISA}} )
            )
        )
    );


    (
        (
            CORE::say(
                ( ('Sidef::Runtime::94252246381296::main::Str1')->call )
                ->is_a('Sidef::Runtime::94252246381296::main::Str1')
            )
        ) ? Sidef::Types::Bool::Bool::TRUE : Sidef::Types::Bool::Bool::FALSE
    );
    $t94252249373888 = Sidef::Types::Block::Block->new(
        code => sub {
            my ($c94252249372688) = @_;
            my @return;
            END94252246569872: @return;
        },
        type => "func",
        name => "t",
        vars => [
            {
                name => "c",
                subset =>
"Sidef\:\:Runtime\:\:94252248411112\:\:main\:\:S94252248411112",
                subset_blocks => [
                    sub { my ($_94252248371632) = @_; ($_94252248371632)->len }
                ]
            }
        ],
        table => { "c" => 0 }
    );
}
