package App::Termcast::Server::Web::Hippie::Handle;
use Moose;

has handle => (
    is => 'ro',
    required => 1,
);

has stream => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has vt => (
    is => 'ro',
    isa => 'Term::VT102::Incremental',
    lazy    => 1,
    builder => '_build_vt',
    clearer => 'clear_vt',
);

around BUILDARGS => sub {
    my $orig = shift;
    my $self = shift;
    my %args = @_;

    if ($args{cols} and $args{lines} and not $args{vt}) {
        $args{vt} = $self->make_vt(
            rows => delete $args{lines},
            cols => delete $args{cols},
        );
    }

    $self->$orig(%args);
};

sub _build_vt { shift->make_vt; }

sub make_vt {
    my $self = shift;
    my %args = @_;

    my $vt = Term::VT102::Incremental->new(%args);
    #$vt->vt->option_set('LINEWRAP', 1);

    return $vt;
}

sub send_to_browser {
    my $self = shift;
    my $buf  = shift;

    $self->vt;
    $self->vt->process($buf);
    my $updates = $self->vt->get_increment();

    $self->handle->send_msg($updates);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;