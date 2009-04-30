package MyApp;
use Catalyst::Runtime '5.70';
use Catalyst;
use Carp;
use Data::Dump qw( dump );

our $VERSION = '0.04';

__PACKAGE__->config( foo => 'bar' );
__PACKAGE__->config->{bad} = 'juju';

__PACKAGE__->setup();

#warn dump MyApp->config;

Class::C3::initialize();    # for REST

#warn dump MyApp->config;

my @temp_files;

sub push_temp_files {
    shift;
    push( @temp_files, @_ );
}

END {
    for my $f (@temp_files) {
        warn "unlinking $f\n" if $ENV{CATALYST_DEBUG};
        $f->remove;
    }
}

sub foo : Local {

    my ( $self, $c, @arg ) = @_;

    #carp "inc_path: " . dump $c->model('File')->inc_path;

    my $file
        = $c->model('File')
        ->new_object(
        file => [ $c->model('File')->inc_path->[0], 'crud_temp_file' ] );

    $self->push_temp_files($file);

    #carp dump $file;

    $file->content('hello world');

    $file->create or croak "failed to create $file : $!";

    my $filename = $file->basename;

    #carp "filename = $filename";

    $file = $c->model('File')->fetch( file => $filename );

    #carp dump $file;

    $file->read;

    if ( $file->content ne 'hello world' ) {
        croak "bad read";
    }

    $file->content('change the text');

    #carp $file;

    $file->update;

    $file = $c->model('File')->fetch( file => $filename );

    #carp $file;

    $c->res->body("foo is a-ok");

}

sub autoload : Local {
    my ( $self, $c ) = @_;

    my $file = $c->model('File')->new_object(
        file    => [ $c->model('File')->inc_path->[0], 'autoload_test' ],
        content => 'test AUTOLOAD black magic'
    );

    $self->push_temp_files($file);

    $file->create;

    #warn "testing basename on $file";

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
