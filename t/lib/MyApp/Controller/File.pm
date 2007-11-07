package MyApp::Controller::File;
use strict;
use base qw( CatalystX::CRUD::Controller );
use Carp;
use Data::Dump qw( dump );
use File::Temp;

# test the view_on_single_result method
# search for a file where we know there is only one
# and then check for a redirect response code
# NOTE we have to fake up the primary_key method
# to just return the file path (the unique id)
# and the form class to just use a dummy

{

    package NoForm;
    sub new { return bless( {}, shift(@_) ); }
}

__PACKAGE__->config(
    primary_key => 'absolute',
    form_class  => 'NoForm',
    model_name  => 'File',
);

sub do_search {

    my ( $self, $c, @arg ) = @_;

    $self->config->{view_on_single_result} = 1;

    my $tmpf = File::Temp->new;
    
    my $file = $c->model( $self->model_name )->new_object( file => $tmpf->filename );
    
    if ( my $uri = $self->view_on_single_result( $c, [$file] ) ) {
        $c->response->redirect($uri);
        return;
    }

    $self->throw_error("view_on_single_result failed");

}


1;
