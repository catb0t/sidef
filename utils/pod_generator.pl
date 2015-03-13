#!/usr/bin/perl

use utf8;
use 5.010;
use strict;
use autodie;
use warnings;

use lib qw(.);
use open IO => ':encoding(UTF-8)';

use File::Find qw(find);
use List::Util qw(first);
use File::Basename qw(basename);
use File::Spec::Functions qw(curdir splitdir catfile);

my $dir = shift() // die "usage: $0 sidef/lib\n";

my %esc = (
           '>' => 'gt',
           '<' => 'lt',
          );

my %ignored_subs = map { $_ => 1 } qw<
  BEGIN
  ISA
  (""
  ((
  (bool
  AUTOLOAD
  DESTROY
  >;

my %ignored_methods = (
                       'Sidef'                          => [qw(new VERSION Types:: a b)],
                       'Sidef::Types::Block::Return'    => [qw(get_obj new)],
                       'Sidef::Types::Block::Break'     => [qw(new)],
                       'Sidef::Variable::Variable'      => [qw(set_value is_defined get_type get_value new)],
                       'Sidef::Variable::Ref'           => [qw(get_var new)],
                       'Sidef::Variable::My'            => [qw(new)],
                       'Sidef::Variable::Init'          => [qw(new)],
                       'Sidef::Variable::InitMy'        => [qw(new)],
                       'Sidef::Module::Require'         => [qw(new)],
                       'Sidef::Sys::Sys'                => [qw(new)],
                       'Sidef::Math::Math'              => [qw(new)],
                       'Sidef::Time::Localtime'         => [qw(new)],
                       'Sidef::Time::Gmtime'            => [qw(new)],
                       'Sidef::Types::Nil::Nil'         => [qw(get_value new)],
                       'Sidef::Types::Bool::If'         => [qw(new)],
                       'Sidef::Types::Bool::While'      => [qw(new)],
                       'Sidef::Types::Bool::Ternary'    => [qw(new)],
                       'Sidef::Types::Glob::DirHandle'  => [qw(new)],
                       'Sidef::Types::Glob::FileHandle' => [qw(new get_value)],
                       'Sidef::Types::Glob::Backtick'   => [qw(new)],
                       'Sidef::Types::Glob::PipeHandle' => [qw(new get_value)],
                       'Sidef::Types::Glob::Stat'       => [qw(new)],
                       'Sidef::Types::Block::For'       => [qw(new)],
                       'Sidef::Types::Block::Switch'    => [qw(new)],
                       'Sidef::Types::Block::Try'       => [qw(new)],
                       'Sidef::Types::Block::Code'      => [qw(new a b)],
                       'Sidef::Types::Block::Given'     => [qw(new)],
                       'Sidef::Types::Block::Continue'  => [qw(new)],
                       'Sidef::Types::Regex::Matches'   => [qw(new)],
                       'Sidef::Types::Regex::Regex'     => [qw(new)],
                       'Sidef::Types::Black::Hole'      => [qw(new)],
                       'Sidef::Types::Array::Array'     => [qw(get_value a b)],
                       'Sidef::Types::Number::Number'   => [qw(get_value)],
                       'Sidef::Types::String::String'   => [qw(get_value a b)],
                       'Sidef::Types::Byte::Bytes'      => [qw(decode_utf8)],
                       'Sidef::Types::Glob::Fcntl'      => [qw(new)],
                       'Sidef::Types::Hash::Hash'       => [qw(a b)],
                      );

my %ignored_modules = map { $_ => 1 } qw (
  Sidef::Exec
  Sidef::Parser
  Sidef::Args::Args
  Sidef::Sys::SIG
  Sidef::Types::Array::HCArray
  Sidef::Types::Number::NumberFast
  Sidef::Types::Number::NumberInt
  Sidef::Types::Number::NumberRat
  Sidef::Object::Unary
  );

my $name = basename($dir);
if ($name ne 'lib') {
    die "error: '$dir' is not a lib directory!";
}

chdir $dir;

find {
    no_chdir => 1,
    wanted   => sub {
        /\.pm\z/ && -f && process_file($_);
    },
} => curdir();

sub parse_pod_file {
    my ($file) = @_;

    my %data;
    open my $fh, '<', $file;

    my $meth = 0;
    while (defined(my $line = <$fh>)) {

        if ($meth) {
            my $sec = '';
            $sec .= $line;

            until ($line =~ /^=cut\b/ or eof($fh)) {
                $sec .= ($line = <$fh>);
            }

            if ($sec =~ /^=head2\h+(.*\S)/m) {
                $data{$1} = $sec;
            }
        }
        else {
            $data{__HEADER__} .= $line;
        }

        if ($meth == 0 && $line =~ /^=head1\h+METHODS/) {
            $meth = 1;
        }
    }
    close $fh;

    return \%data;
}

sub process_file {
    my ($file) = @_;

    my (undef, @parts) = splitdir($file);
    require join('/', @parts);

    $parts[-1] =~ s{\.pm\z}{};

    my $module = join('::', @parts);

    exists($ignored_modules{$module})
      && return;

    my $mod_methods = do {
        no strict 'refs';
        \%{$module . '::'};
    };

    my %subs;
    foreach my $sub (keys %{$mod_methods}) {

        next if $sub =~ /^_/;
        next if exists $ignored_subs{$sub};

        if (exists $ignored_methods{$module}) {
            if (first { $_ eq $sub } @{$ignored_methods{$module}}) {
                next;
            }
        }

        my $orig_name = $sub;
        my $is_method = lc($sub) ne uc($sub);

        $sub =~ s{([<>])}{E<$esc{$1}>}g;

        my $doc = $is_method ? <<"__POD__" : <<"__POD2__";

=head2 $orig_name

$parts[-1].$sub() -> I<Bool>

Return the

=cut
__POD__

=head2 $orig_name

I<Num> B<$sub> I<Num> -> I<Num>

Return the

=cut
__POD2__

        $subs{$orig_name} = $doc;
    }

    my @keys = keys %subs;

    if ($#keys == -1) {
        warn "[!] No method found for module: $module\n";
        return;
    }

    my $pod_file = catfile(@parts) . '.pod';

    say "** Writing: $pod_file";

    my $pod_data = {};

    (-e $pod_file) && do {
        $pod_data = parse_pod_file($pod_file);
    };

    my %alias_methods;
    foreach my $key (@keys) {
        if (exists $pod_data->{$key}) {
            $subs{$key} = $pod_data->{$key};

            if ($pod_data->{$key} =~ /^Alias(?:es)?:\h*(.*\S)/m) {
                my @aliases = split(/,\h+/, $1);
                foreach my $alias (@aliases) {
                    $alias =~ s{[^>]+\z}{};
                    if ($alias =~ m{^[A-Z]<(.+)>\z}) {
                        (my $method = $1) =~ s{\(\)\z}{};

                        $method =~ s{E<lt>}{<}g;
                        $method =~ s{E<gt>}{>}g;

                        undef $alias_methods{$method};
                    }
                }
            }
        }
    }

    open my $fh, '>', $pod_file;

    if (exists $pod_data->{__HEADER__}) {
        print {$fh} $pod_data->{__HEADER__};
    }
    else {
        my $header = <<"HEADER";

=encoding utf8

=head1 NAME

$module

=head1 DESCRIPTION

This object is ...

=head1 SYNOPSIS

var obj = ($parts[-1].new(...));

HEADER

        my @isa = @{exists($mod_methods->{ISA}) ? $mod_methods->{ISA} : []};

        if (@isa) {
            $header .= <<'HEADER';

=head1 INHERITS

Inherits methods from:

HEADER

            $header .= join("\n", map { "\t* $_" } @isa);
            $header .= "\n\n";
        }

        $header .= <<"HEADER";
=head1 METHODS

HEADER

        print {$fh} $header;
    }

    foreach my $method (
                        sort { (lc($a =~ tr/_//dr) cmp lc($b =~ tr/_//dr)) || ($a cmp $b) }
                        grep { not exists $alias_methods{$_} }
                        keys %subs
      ) {
        print {$fh} $subs{$method};
    }
}
