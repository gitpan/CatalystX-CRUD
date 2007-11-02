package MyApp;
use Catalyst::Runtime '5.70';
use Catalyst;
use Carp;
use Data::Dump qw( dump );
use File::Temp 'tempfile';

our $VERSION = '0.01';

__PACKAGE__->setup();

sub foo : Local {

    my ( $self, $c, @arg ) = @_;

    my ( undef, $tempf ) = tempfile();

    # have to set inc_path() after we create our first file
    # so that we know where the temp dir is.

    #carp "inc_path: " . dump $c->model('File')->inc_path;

    my $file = $c->model('File')->new_object( file => $tempf );

    #carp dump $file;

    $file->buffer('hello world');

    $file->create;

    my $filename = $file->basename;

    #carp "filename = $filename";

    # set inc_path now that we know dir
    $c->model('File')->config->{inc_path} = [ $file->dir ];

    #carp "inc_path: " . dump $c->model('File')->inc_path;

    $file = $c->model('File')->fetch( file => $filename );

    #carp dump $file;

    $file->read;

    if ( $file->buffer ne 'hello world' ) {
        croak "bad read";
    }

    $file->buffer('change the text');

    #carp dump $file;

    $file->update;

    $file = $c->model('File')->fetch( file => $filename );

    $file->delete;

    $c->res->body("foo is a-ok");

}

sub autoload : Local {
    my ( $self, $c ) = @_;

    my ( undef, $tempf ) = tempfile();

    # have to set inc_path() after we create our first file
    # so that we know where the temp dir is.

    my $file = $c->model('File')->new_object( file => $tempf );

    warn "testing basename on $file";

    # test that calling $file->foo actually calls foo()
    # on $file->delegate and not $file itself
    eval { $file->basename };
    if ($@) {
        warn "failed to call ->basename on $file: $@";
        return;
    }

    unless ( $file->can('basename') ) {
        warn "can't can(basename) but can ->basename";
        return;
    }

    # test that we can still call read() and can(read) on the parent object
    eval { $file->read };
    if ($@) {
        warn "$file cannot read() - $@ $!";
        return;
    }

    eval { $file->can('read') };
    if ($@) {
        warn "$file cannot can(read) - $@ $!";
        return;
    }
  


    $c->res->body("autoload is a-ok");

}

1;
