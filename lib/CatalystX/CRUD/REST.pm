package CatalystX::CRUD::REST;
use strict;
use warnings;
use base qw( CatalystX::CRUD::Controller );
use Carp;
use Class::C3;

our $VERSION = '0.26';

=head1 NAME

CatalystX::CRUD::REST - REST-style controller for CRUD

=head1 SYNOPSIS

    # create a controller
    package MyApp::Controller::Foo;
    use strict;
    use base qw( CatalystX::CRUD::REST );
    
    __PACKAGE__->config(
                    form_class              => 'MyForm::Foo',
                    init_form               => 'init_with_foo',
                    init_object             => 'foo_from_form',
                    default_template        => 'path/to/foo/edit.tt',
                    model_name              => 'Foo',
                    primary_key             => 'id',
                    view_on_single_result   => 0,
                    page_size               => 50,
                    );
                    
    1;
    
    # now you can manage Foo objects using your MyForm::Foo form class
    # with URIs at:
    #  foo/<pk>
    # and use the HTTP method name to indicate the appropriate action.
    # POST      /foo                -> create new record
    # GET       /foo                -> list all records
    # PUT       /foo/<pk>           -> update record
    # DELETE    /foo/<pk>           -> delete record
    # GET       /foo/<pk>           -> view record
    # GET       /foo/<pk>/edit_form -> edit record form
    # GET       /foo/create_form    -> create record form

    
=head1 DESCRIPTION

CatalystX::CRUD::REST is a subclass of CatalystX::CRUD::Controller.
Instead of calling RPC-style URIs, the REST API uses the HTTP method name
to indicate the action to be taken.

See CatalystX::CRUD::Controller for more details on configuration.

The REST API is designed with identical configuration options as the RPC-style
Controller API, so that you can simply change your @ISA chain and enable
REST features for your application.

=cut

=head1 METHODS

=head2 edit_form

Acts just like edit() in base Controller class, but with a RESTful name.

=head2 create_form

Acts just like create() in base Controller class, but with a RESTful name.

=cut

sub create_form : Local {
    my ( $self, $c ) = @_;
    $self->fetch( $c, 0 );
    $self->edit($c);
}

sub edit_form : PathPart Chained('fetch') Args(0) {
    my ( $self, $c ) = @_;
    return $self->edit($c);
}

=head2 create

Redirects to create_form().

=cut

sub create : Local {
    my ( $self, $c ) = @_;
    $c->res->redirect( $c->uri_for('create_form') );
}

=head2 default

Attribute: Private

Calls the appropriate method based on the HTTP method name.

=cut

my %http_method_map = (
    'POST'   => 'save',
    'PUT'    => 'save',
    'DELETE' => 'rm',
    'GET'    => 'view'
);

sub default : Path {
    my ( $self, $c, @arg ) = @_;

    my $oid = shift @arg;
    my $rpc = shift @arg;    # RPC compat
    $c->log->debug("default OID: $oid") if $c->debug;

    my $method = $self->req_method($c);
    if ( !defined $oid && $method eq 'GET' ) {
        $c->action->name('list');
        $c->action->reverse( join( '/', $c->action->namespace, 'list' ) );
        return $self->list($c);
    }

    # everything else requires fetch()
    $self->fetch( $c, $oid );

    # what RPC-style method to call
    my $to_call = defined($rpc) ? $rpc : $http_method_map{$method};

    # backwards compat naming for RPC style
    if ( $to_call =~ m/^(create|edit)$/ ) {
        $to_call .= '_form';
    }
    $c->log->debug("$method -> $to_call") if $c->debug;

    # so TT (others?) auto-template-deduction works just like RPC style
    $c->action->name($to_call);
    $c->action->reverse( join( '/', $c->action->namespace, $to_call ) );

    return $self->can($to_call) ? $self->$to_call($c) : $self->view($c);
}

=head2 req_method( I<context> )

Internal method. Returns the HTTP method name, allowing
POST to serve as a tunnel when the C<_http_method> or
C<x-tunneled-method> param is present. 
Since most browsers do not support PUT or DELETE
HTTP methods, you can use the special param to tunnel
the desired HTTP method and then POST instead.

=cut

my @tunnel_param_names = qw( x-tunneled-method _http_method );

sub req_method {
    my ( $self, $c ) = @_;
    if ( uc( $c->req->method ) eq 'POST' ) {
        for my $name (@tunnel_param_names) {
            if ( exists $c->req->params->{$name} ) {
                return uc( $c->req->params->{$name} );
            }
        }
    }
    return uc( $c->req->method );
}

=head2 edit( I<context> )

Overrides base method to disable chaining.

=cut

sub edit {
    my ( $self, $c ) = @_;
    return $self->next::method($c);
}

=head2 view( I<context> )

Overrides base method to disable chaining.

=cut

sub view {
    my ( $self, $c ) = @_;
    return $self->next::method($c);
}

=head2 save( I<context> )

Overrides base method to disable chaining.

=cut

sub save {
    my ( $self, $c ) = @_;
    return $self->next::method($c);
}

=head2 rm( I<context> )

Overrides base method to disable chaining.

=cut

sub rm {
    my ( $self, $c ) = @_;
    return $self->next::method($c);
}

=head2 postcommit( I<context>, I<object> )

Overrides base method to redirect to REST-style URL.

=cut

sub postcommit {
    my ( $self, $c, $o ) = @_;
    my $pk = $self->primary_key;

    if ( $c->action->name eq 'rm' ) {
        $c->response->redirect( $c->uri_for('') );
    }
    else {
        $c->response->redirect( $c->uri_for( '', $o->$pk ) );
    }

    1;
}

1;

__END__

=head1 AUTHOR

Peter Karman, C<< <perl at peknet.com> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-catalystx-crud at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=CatalystX-CRUD>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc CatalystX::CRUD

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/CatalystX-CRUD>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/CatalystX-CRUD>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=CatalystX-CRUD>

=item * Search CPAN

L<http://search.cpan.org/dist/CatalystX-CRUD>

=back

=head1 COPYRIGHT & LICENSE

Copyright 2008 Peter Karman, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

