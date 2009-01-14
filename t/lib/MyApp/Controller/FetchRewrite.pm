package MyApp::Controller::FetchRewrite;
use strict;
use base qw( CatalystX::CRUD::Test::Controller );
use Carp;
use Data::Dump qw( dump );
use File::Temp;
use MyApp::Form;

__PACKAGE__->config(
    primary_key   => 'absolute',
    form_class    => 'MyApp::Form',
    form_fields   => [qw( file content )],
    model_adapter => 'CatalystX::CRUD::ModelAdapter::File',
    model_name    => 'File',
    primary_key   => 'file',
    init_form     => 'init_with_file',
    init_object   => 'file_from_form',
);

# append the namespace qualifier for objects
sub _parse_PathPrefix_attr {
    my ( $self, $c, $name, $value ) = @_;
    return PathPart => $self->path_prefix . '/id';
}

1;
