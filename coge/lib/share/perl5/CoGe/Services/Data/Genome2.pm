package CoGe::Services::Data::Genome2;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON;
use CoGeX;
use CoGe::Services::Auth;

sub search {
    my $self = shift;
    my $search_term = $self->stash('term');

    # Validate input
    if (!$search_term or length($search_term) < 3) {
        $self->render(json => { error => { Error => 'Search term is shorter than 3 characters' } });
        return;
    }

    # Authenticate user and connect to the database
    #my ( $db, $user, $conf ) = CoGe::Accessory::Web->init(ticket => $key);
    my ($db, $user) = CoGe::Services::Auth::init($self);

    # Search genomes
    my $search_term2 = '%' . $search_term . '%';
    my @genomes = $db->resultset("Genome")->search(
        \[
            'genome_id = ? OR name LIKE ? OR description LIKE ?',
            [ 'genome_id', $search_term  ],
            [ 'name',        $search_term2 ],
            [ 'description', $search_term2 ]
        ]
    );
    
    # Search organisms
    my @organisms = $db->resultset("Organism")->search(
        \[
            'name LIKE ? OR description LIKE ?',
            [ 'name',        $search_term2 ],
            [ 'description', $search_term2 ]
        ]
    );
    
    # Combine matching genomes and organisms, preventing duplicates
    my %unique;
    map { $unique{ $_->id } = $_ } @genomes;
    foreach my $organism (@organisms) {
        map { $unique{ $_->id } = $_ } $organism->genomes;
    }

    # Filter response
    my @filtered = grep {
        !$_->restricted || (defined $user && $user->has_access_to_genome($_))
    } values %unique;

    # Format response
    my @result = map {
      {
        id => int($_->id),
        name => $_->name,
        description => $_->description,
        link => $_->link,
        version => $_->version,
        organism_id  => int($_->organism->id),
        sequence_type => {
            name => $_->type->name,
            description => $_->type->description,
        },
        restricted => $_->restricted ? Mojo::JSON->true : Mojo::JSON->false,
        chromosome_count => int($_->chromosome_count),
        organism => {
            id => int($_->organism->id),
            name => $_->organism->name,
            description => $_->organism->description
        }
      }
    } @filtered;

    $self->render(json => { genomes => \@result });
}

sub fetch {
    my $self = shift;
    my $id = int($self->stash('id'));

    # Authenticate user and connect to the database
    #my ( $db, $user, $conf ) = CoGe::Accessory::Web->init(ticket => $key);
    my ($db, $user) = CoGe::Services::Auth::init($self);

    my $genome = $db->resultset("Genome")->find($id);
    unless (defined $genome) {
        $self->render(json => {
            error => { Error => "Item not found"}
        });
        return;
    }

    unless ( !$genome->restricted || (defined $user && $user->has_access_to_genome($genome)) ) {
        $self->render(json => {
            error => { Auth => "Access denied"}
        }, status => 401);
        return;
    }

    # Format metadata
    my @metadata = map {
        {
            text => $_->annotation,
            link => $_->link,
            type => $_->type->name,
            type_group => $_->type->group
        }
    } $genome->annotations;

    $self->render(json => {
        id => int($genome->id),
        name => $genome->name,
        description => $genome->description,
        link => $genome->link,
        version => $genome->version,
        restricted => $genome->restricted ? Mojo::JSON->true : Mojo::JSON->false,
        organism => {
            id => int($genome->organism->id),
            name => $genome->organism->name,
            description => $genome->organism->description
        },
        sequence_type => {
            name => $genome->type->name,
            description => $genome->type->description,
        },
        chromosome_count => int($genome->chromosome_count),
        experiments => [ map { int($_->id) } $genome->experiments ],
        metadata => \@metadata
    });
}

1;
