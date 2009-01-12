package MyApp::Controller::File;
use strict;
use base qw( CatalystX::CRUD::Test::Controller );
use Carp;
use Data::Dump qw( dump );
use File::Temp;
use MyApp::Form;

__PACKAGE__->config(
    primary_key           => 'absolute',
    form_class            => 'MyApp::Form',
    form_fields           => [qw( file content )],
    model_name            => 'File',
    primary_key           => 'file',
    init_form             => 'init_with_file',
    init_object           => 'file_from_form',
    view_on_single_result => 1,
);

# test the view_on_single_result method
# search for a file where we know there is only one
# and then check for a redirect response code

sub do_search {

    my ( $self, $c, @arg ) = @_;

    $self->config->{view_on_single_result} = 1;

    my $tmpf = File::Temp->new;

    my $file = $c->model( $self->model_name )
        ->new_object( file => $tmpf->filename );

    if ( my $uri = $self->uri_for_view_on_single_result( $c, [$file] ) ) {
        $c->response->redirect($uri);
        return;
    }

    $self->throw_error("view_on_single_result failed");

}

1;
