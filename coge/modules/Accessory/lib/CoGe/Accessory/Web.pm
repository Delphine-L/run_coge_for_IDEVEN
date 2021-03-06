package CoGe::Accessory::Web;
use v5.10;

use strict;
use base 'Class::Accessor';
use Data::Dumper;
use Data::Validate::URI qw(is_uri);
use Carp qw(cluck);
use CoGeX;
use DBIxProfiler;
use CGI::Carp('fatalsToBrowser');
use CGI;
use CGI::Cookie;
use File::Path;
use File::Basename;
use File::Temp;
use File::Spec::Functions;
use HTML::Template;
use LWP::Simple qw(!get !head !getprint !getstore !mirror);
use LWP::UserAgent;
use JSON;
use HTTP::Request;
use XML::Simple;
use CoGe::Accessory::LogUser qw(get_cookie_session);
use Digest::MD5 qw(md5_base64);
use POSIX qw(!tmpnam !tmpfile);
use Mail::Mailer;
use URI;

=head1 NAME

Web

=head1 SYNOPSIS

use Web

=head1 DESCRIPTION

=head1 AUTHOR

Eric Lyons

=head1 COPYRIGHT

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

=cut

our($CONF, $VERSION, @ISA, @EXPORT, @EXPORT_OK, $Q, $TEMPDIR, $BASEDIR,
    $PAYLOAD_ERROR, $NOT_FOUND);

BEGIN {
    require Exporter;

    $BASEDIR = ( $ENV{COGE_HOME} ? $ENV{COGE_HOME} : '/opt/apache/coge/web/' );
    $VERSION = 0.1;
    $TEMPDIR = $BASEDIR . "tmp";
    @ISA     = ( qw (Exporter Class::Accessor) );
    @EXPORT  = qw( get_session_id check_filename_taint check_taint gunzip gzip 
                   send_email get_defaults set_defaults url_for get_job 
                   schedule_job render_template );

    $PAYLOAD_ERROR = "The request could not be decoded";
    $NOT_FOUND = "The action could not be found";

    __PACKAGE__->mk_accessors(
        'restricted_orgs', 'basefilename', 'basefile', 'logfile',
        'sqlitefile'
    );
}

# TODO: instead of returning a list, this routine should return a "page object"
sub init {
    my ( $self, %opts ) = self_or_default(@_);
    my $ticket = $opts{ticket}; # optional cas ticket for retrieving user
    my $url    = $opts{url};    # optional redirect url to pass to cas authentication
    my $cgi    = $opts{cgi};    # optional CGI object
    my $debug  = $opts{debug};  # optional flag for enabling debugging messages
    my $page_title = $opts{page_title}; # optional page title
    my $ticket_type = $opts{ticket_type}; #optional ticket type (saml or proxy)

    if ($cgi) {
    	$ticket = $cgi->param('ticket') || undef;
    	$url    = $cgi->url;
    }

    # Get config
    $CONF = get_defaults();

    # Connec to DB
    my $db = CoGeX->dbconnect($CONF);
    if ($debug) { # enable ORM debugging if requested
		$db->storage->debugobj(new DBIxProfiler());
		$db->storage->debug(1);
    }

    # Get user
    my $user;
    if ($ticket) {
    	if (defined $ticket_type and $ticket_type eq 'proxy') { # mdb added 12/10/13 hackathon1
    		($user) = login_cas_proxy(
		    	cookie_name => $CONF->{COOKIE_NAME},
		        ticket   => $ticket,
		        coge     => $db,
		        this_url => $url
		    );
    	}
    	else {
    	    ($user) = login_cas_saml(
                cookie_name => $CONF->{COOKIE_NAME},
                ticket   => $ticket,
                coge     => $db,
                this_url => $url
            );
    	}
    }
    ($user) = CoGe::Accessory::LogUser->get_user(
        cookie_name => $CONF->{COOKIE_NAME},
        coge        => $db
    ) unless $user;

	my $link;
    if ($page_title) { # This is a page access and not a web service request
        # Make tmp directory
        my $tempdir = $CONF->{TEMPDIR} . '/' . $page_title . '/';
        mkpath( $tempdir, 0, 0777 ) unless -d $tempdir;

		# Skip tiny link generation and auto-logging if ajax request
		if (not is_ajax($cgi)) {
	        # Get tiny link
	        $link = get_tiny_link(
	            url => 'http://' . $ENV{SERVER_NAME} . $ENV{REQUEST_URI},
	        );

            # erb 10/07/2014 - remove unused generic logging issue 516
	        # Log this page access
            #CoGe::Accessory::Web::log_history(
		    #    db          => $db,
		    #    user_id     => $user->id,
		    #   	page        => $page_title,
		    #  	description => 'page access',
		    #    link        => $link
		    #);
		}
    }

    print STDERR "Web::init ticket=" . ($ticket ? $ticket : '') . " url=" . ($url ? $url : '') . " page_title=" . ($page_title ? $page_title : '') . " user=" . ($user ? $user->name : '') . "\n";

    return ( $db, $user, $CONF, $link );
}

sub render_template {
    my ($template_name, $opts) = @_;

    my $template_file = catfile(get_defaults()->{TMPLDIR}, $template_name);

    unless(-r $template_file) {
        cluck "error: template=$template_file could not be found";
        return;
    }

    my $template = HTML::Template->new( filename => $template_file );

    $template->param($opts);
    return $template->output;
}

sub get_defaults {
    return $CONF if ($CONF);

    my ( $self, $conf_file ) = self_or_default(@_);
    $conf_file = $BASEDIR . "/coge.conf" unless defined $conf_file;
    #print STDERR "Web::get_defaults $conf_file\n";
    unless ( -r $conf_file ) {
        print STDERR
qq{Either no configuration file was specified or unable to read file ($conf_file).
A valid configuration file must be specified or very little will work!};
        return 0;
    }
    
    open( IN, $conf_file );
    my %items;
    while (<IN>) {
        chomp;
        next if /^#/;
        next unless $_;
        my ( $name, $path ) = split( /\s+/, $_, 2 );
        $items{$name} = $path;
    }
    close IN;

    # mdb added 4/10/14 - add path to the file that was loaded
    $items{_CONFIG_PATH} = $conf_file;

    $CONF = \%items;
    return $CONF;
}

sub set_defaults {
    my $NEW_CONF = shift;
    $CONF = \(%$CONF, %$NEW_CONF);
}

sub is_ajax {
	my ( $self, $form) = self_or_default(@_);
	return 0 unless $form;
    my %args  = $form->Vars;
    my $fname = $args{'fname'};
    return (defined $fname and $fname ne '');
}

sub dispatch {
    my ( $self, $form, $functions, $default_sub ) = self_or_default(@_);
    my $content_type = $ENV{'CONTENT_TYPE'};

    if ($content_type =~ /application\/json/) {
        my $payload = $form->param('POSTDATA');
        my ($params, $resp);

        eval {
            $params = decode_json($payload) if $payload;
        };

        if ($params) {
            my $fname = $params->{fname};

            if (not defined $functions->{$fname}) {
                carp "Web::dispatch: function '$fname' not found!";
                $resp = encode_json({ error => { NOT_FOUND => $NOT_FOUND }});
            } else {
                $resp = $functions->{$fname}->($params);
            }
        } else {
            $resp = encode_json({ error => { PAYLOAD => $PAYLOAD_ERROR }});
        }

        print $form->header, $resp;
    } else {
        my %args  = $form->Vars;
        my $fname = $args{'fname'};
        if ($fname) {
            die "Web::dispatch: function '$fname' not found!" if (not defined $functions->{$fname});
            #my %args = $form->Vars;
            #print STDERR Dumper \%args;
            if ( $args{args} ) {
                my @args_list = split( /,/, $args{args} );
                print $form->header, $functions->{$fname}->(@args_list);
            }
            else {
                print $form->header, $functions->{$fname}->(%args);
            }
        }
        else {
            print $form->header, $default_sub->();
        }
    }
}

sub dataset_search_for_feat_name {
    my ( $self, $accn, $num, $dsid, $featid, $coge ) = self_or_default(@_);
    $num = 1 unless $num;
    return (
qq{<input type="hidden" id="dsid$num">\n<input type="hidden" id="featid$num">},
        $num
    ) unless $accn;
    my $html;
    my %sources;
    my %restricted_orgs = %{ $self->restricted_orgs } if $self->restricted_orgs;
    my $rs = $coge->resultset('Dataset')->search(
        { 'feature_names.name' => $accn },
        {
            'join' => { 'features' => 'feature_names' },
            'prefetch' => [ 'datasource', 'organism' ]
        }
    );
    while ( my $ds = $rs->next() ) {
        my $name    = $ds->name;
        my $ver     = $ds->version;
        my $desc    = $ds->description;
        my $sname   = $ds->datasource->name;
        my $ds_name = $ds->name;
        my $org     = $ds->organism->name;
        my $title   = "$org: $ds_name ($sname, v$ver)";
        next if $restricted_orgs{$org};
        $sources{ $ds->id } = { title => $title, version => $ver };
    }
    if ( keys %sources ) {
        $html .= qq{
 <SELECT name = "dsid$num" id= "dsid$num" onChange="feat_search(['accn$num','dsid$num', 'args__$num'],['feat$num']);" >
 };
        foreach my $id (
            sort { $sources{$b}{version} <=> $sources{$a}{version} }
            keys %sources
          )
        {
            my $val = $sources{$id}{title};
            $html .= qq{  <option value="$id"};
            $html .= qq{ selected } if $dsid && $id == $dsid;
            $html .= qq{>$val\n};
        }
        $html .= qq{</SELECT>\n};
        my $count = scalar keys %sources;
        $html .= qq{<font class=small>($count)</font>};
    }
    else {
        $html .=
qq{Accession not found <input type="hidden" id="dsid$num">\n<input type="hidden" id="featid$num">\n};
    }
    return ( $html, $num );
}

sub feat_search_for_feat_name {
    my ( $self, $accn, $dsid, $num, $coge ) = self_or_default(@_);
    return qq{<input type="hidden" id="featid$num">\n} unless $dsid;
    my @feats;
    my $rs = $coge->resultset('Feature')->search(
        {
            'feature_names.name' => $accn,
            'dataset.dataset_id' => "$dsid",
        },
        {
            'join'     => [ 'feature_type', 'dataset', 'feature_names' ],
            'prefetch' => [ 'feature_type', 'dataset' ],
        }
    );
    my %seen;
    while ( my $f = $rs->next() ) {
        next unless $f->dataset->id == $dsid;

        #	next if $f->feature_type->name =~ /CDS/i;
        #	next if $f->feature_type->name =~ /RNA/i;
        push @feats, $f unless $seen{ $f->id };
        $seen{ $f->id } = 1;
    }
    my $html;
    if (@feats) {
        $html .= qq{<SELECT name = "featid$num" id = "featid$num" >};
        foreach my $feat ( sort { $a->type->name cmp $b->type->name } @feats ) {
            my $loc = "("
              . $feat->type->name
              . ") Chr:"
              . $feat->chromosome . " "
              . $feat->start . "-"
              . $feat->stop;

#working here, need to implement genbank_location_string before I can progress.  Need
            $loc =~ s/(complement)|(join)//g;
            my $fid = $feat->id;
            $html .= qq {  <option value="$fid">$loc \n};
        }
        $html .= qq{</SELECT>\n};
        my $count = scalar @feats;
        $html .= qq{<font class=small>($count)</font>};
    }
    else {
        $html .= qq{<input type="hidden" id="featid$num">\n};
    }
    return $html;
}

sub self_or_default {    #from CGI.pm
    return @_
      if defined( $_[0] )
          && ( !ref( $_[0] ) )
          && ( $_[0] eq 'CoGe::Accessory::Web' );
    unless (
        defined( $_[0] )
        && ( ref( $_[0] ) eq 'CoGe::Accessory::Web'
            || UNIVERSAL::isa( $_[0], 'CoGe::Accessory::Web' )
        )                # slightly optimized for common case
      )
    {
        $Q = CoGe::Accessory::Web->new unless defined($Q);
        unshift( @_, $Q );
    }
    return wantarray ? @_ : $Q;
}

sub get_session_id {
    my ($user_name, $remote_ip) = @_;
    my $session_id = md5_base64( $user_name . $remote_ip );
    $session_id =~ s/\+/1/g;
    return $session_id;
}

sub logout_coge { # mdb added 3/24/14, issue 329
    my $self        = shift;
    my %opts        = @_;
    my $coge        = $opts{coge};
    my $user        = $opts{user};
    my $form        = $opts{form}; # CGI form for calling page
    my $url         = $opts{url};
    $url = $form->url() unless $url;
    print STDERR "Web::logout_coge url=", ($url ? $url : ''), "\n";

    # Delete user session from db
    my $session_id = get_cookie_session(cookie_name => $CONF->{COOKIE_NAME})
        || get_session_id($user->user_name, $ENV{REMOTE_ADDR});

    my ($session) = $coge->resultset('UserSession')->find( { session => $session_id } );
    $session->delete if $session;

    print "Location: ", $form->redirect($url);
}

sub logout_cas {
    my $self        = shift;
    my %opts        = @_;
    my $coge        = $opts{coge};
    my $user        = $opts{user};
    my $form        = $opts{form}; # CGI form for calling page
    my $url         = $opts{url};
    $url = $form->url() unless $url;
    print STDERR "Web::logout_cas url=", ($url ? $url : ''), "\n";

    # Delete user session from db
    my $session_id = get_cookie_session(cookie_name => $CONF->{COOKIE_NAME})
        || get_session_id($user->user_name, $ENV{REMOTE_ADDR});

    my ($session) = $coge->resultset('UserSession')->find( { session => $session_id } );
    $session->delete if $session;

    print "Location: ", $form->redirect(get_defaults()->{CAS_URL} . "/logout?service=" . $url . "&gateway=1");
}

sub login_cas_proxy {
    my ( $self, %opts ) = self_or_default(@_);
    my $cookie_name = $opts{cookie_name};
    my $ticket      = $opts{ticket};        # CAS ticket from iPlant
    my $this_url    = $opts{this_url};      # URL to tell CAS to redirect to
    my $coge        = $opts{coge};          # db object
	print STDERR "Web::login_cas_proxy ticket=$ticket this_url=$this_url\n";

	# https://wiki.jasig.org/display/CAS/Proxy+CAS+Walkthrough
	my $ua = new LWP::UserAgent;
    my $request_ua =
      HTTP::Request->new( GET => get_defaults()->{CAS_URL}.'/proxyValidate?service='.$this_url.'&ticket='.$ticket );
    my $response = $ua->request($request_ua);
    my $result   = $response->content;
    print STDERR $result, "\n";
    my ($uname, $fname, $lname, $email);
    if ($result) {
    	( $uname, $fname, $lname, $email ) = parse_proxy_response($result);
    }
    return unless $uname; # Not logged in

    my ($coge_user) = $coge->resultset('User')->search( { user_name => $uname } );
    unless ($coge_user) {
        # Create new user
        $coge_user = $coge->resultset('User')->create(
            {
                user_name   => $uname,
                first_name  => $fname,
                last_name   => $lname,
                email       => $email,
                description => "Validated by iPlant"
            }
        );    #do we have a valid user in the database, if not create
        $coge_user->insert;

		# Log user creation
        log_history(
            db          => $coge,
            user_id     => $coge_user->id,
            page        => 'Web.pm',
            description => 'create user',
        );
    }

    #create a session ID for the user and log
    my $session_id = get_session_id($uname, $ENV{REMOTE_ADDR});
    $coge->log_user( user => $coge_user, session => $session_id );

	# mdb added 10/19/12 - FIXME key/secret are hardcoded - wait: this will get replaced by openauth soon
	#$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0; # this doesn't work for bypassing cert check, need line in apache cfg
    $request_ua =
      HTTP::Request->new( POST => 'https://user.iplantcollaborative.org/api/v1/service/coge/add/' . $uname );
    $request_ua->authorization_basic( get_defaults()->{AUTHNAME}, get_defaults()->{AUTHPASS} );

    #print STDERR "request uri: " . $request_ua->uri . "\n";
    #$request_ua->content($request);
    $request_ua->content_type("text/xml; charset=utf-8");
    $response = $ua->request($request_ua);

    #if ($response->is_success()) {
	    #print STDERR "status_line: " . $response->status_line() . "\n";
	    #my $header = $response->header;
	    $result = $response->content;
	    #print STDERR "content: <begin>$result<end>\n";
    #}
    #else {
    #	print STDERR "bad response\n";
    #}

    #gen and set the web cookie, yum!
    my $c = CoGe::Accessory::LogUser->gen_cookie(
        session     => $session_id,
        cookie_name => $cookie_name,
    );

#    print STDERR "login_cas:  gen_cookie " . (Dumper $c) . "\n";
    print CGI::header( -cookie => [$c] );
    return $coge_user;
}

sub parse_proxy_response {
	my $response = shift;

	if ($response =~ /authenticationSuccess/) {
		my ($user_name) = $response =~ /\<cas\:user\>(.*)\<\/cas\:user\>/;
		my ($first_name) = $response =~ /\<cas\:firstName\>(.*)\<\/cas\:firstName\>/;
		my ($last_name) = $response =~ /\<cas\:lastName\>(.*)\<\/cas\:lastName\>/;
		my ($email) = $response =~ /\<cas\:email\>(.*)\<\/cas\:email\>/;
		print STDERR "parse_proxy_response: user_name=$user_name first_name=$first_name last_name=$last_name email=$email\n";
		return ($user_name, $first_name, $last_name, $email);
	}

	return;
}

sub login_cas_saml {
    my ( $self, %opts ) = self_or_default(@_);
    my $cookie_name = $opts{cookie_name};
    my $ticket      = $opts{ticket};        # CAS ticket from iPlant
    my $this_url    = $opts{this_url};      # URL to tell CAS to redirect to
    my $coge        = $opts{coge};          # db object
	print STDERR "Web::login_cas_saml ticket=$ticket this_url=$this_url\n";

    my $cas_url = get_defaults()->{CAS_URL};
    unless ($cas_url) {
        print STDERR "Web::login_cas_saml: error: CAS_URL not defined in configuration file\n";
        return;
    }

    # Build and execute SAML request
    my $ua = new LWP::UserAgent;
    my $request =
        '<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">'
      . '<SOAP-ENV:Header/><SOAP-ENV:Body><samlp:Request xmlns:samlp="urn:oasis:names:tc:SAML:1.0:protocol"  MajorVersion="1" MinorVersion="1" RequestID="_192.168.167.84.1024506224022"  IssueInstant="2010-05-13T16:43:48.099Z"><samlp:AssertionArtifact>'
      . $ticket
      . '</samlp:AssertionArtifact></samlp:Request></SOAP-ENV:Body></SOAP-ENV:Envelope>';

    my $request_ua =
      HTTP::Request->new(
        #POST => 'https://gucumatz.iplantcollaborative.org/cas/samlValidate?TARGET=' # mdb added 12/5/13 - Hackathon1
        POST => $cas_url . '/samlValidate?TARGET=' . $this_url );
    $request_ua->content($request);
    $request_ua->content_type("text/xml; charset=utf-8");
    my $response = $ua->request($request_ua);
    #print STDERR "SAML response: ", Dumper $response, "\n";
    my $result   = $response->content;
    print STDERR "SAML result: ", Dumper $result, "\n";
    return unless $result;
    
    # Parse user info out of SAML response
    my ( $uname, $fname, $lname, $email ) = parse_saml_response($result);
    return unless $uname; # Not logged in

    # Find user in database
    my ($coge_user) = $coge->resultset('User')->search( { user_name => $uname } );
    unless ($coge_user) {
        # Create new user
        $coge_user = $coge->resultset('User')->create(
            {
                user_name   => $uname,
                first_name  => $fname,
                last_name   => $lname,
                email       => $email,
                description => "Validated by iPlant"
            }
        );    #do we have a valid user in the database, if not create
        $coge_user->insert;

		# Log user creation
        log_history(
            db          => $coge,
            user_id     => $coge_user->id,
            page        => 'Web.pm',
            description => 'create user',
        );
    }

    #create a session ID for the user and log
    my $session_id = get_session_id($uname, $ENV{REMOTE_ADDR});
    $coge->log_user( user => $coge_user, session => $session_id );

	# mdb added 10/19/12 - FIXME key/secret are hardcoded - wait: this will get replaced by openauth soon
	#$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0; # this doesn't work for bypassing cert check, need line in apache cfg
    $request_ua =
      HTTP::Request->new(
        POST => 'https://user.iplantcollaborative.org/api/v1/service/coge/add/' . $uname );
    $request_ua->authorization_basic( get_defaults()->{AUTHNAME}, get_defaults()->{AUTHPASS} );

    #print STDERR "request uri: " . $request_ua->uri . "\n";
    #$request_ua->content($request);
    $request_ua->content_type("text/xml; charset=utf-8");
    $response = $ua->request($request_ua);

    #if ($response->is_success()) {
	    #print STDERR "status_line: " . $response->status_line() . "\n";
	    #my $header = $response->header;
	    $result = $response->content;
	    #print STDERR "content: <begin>$result<end>\n";
    #}
    #else {
    #	print STDERR "bad response\n";
    #}

    #gen and set the web cookie, yum!
    my $c = CoGe::Accessory::LogUser->gen_cookie(
        session     => $session_id,
        cookie_name => $cookie_name,
    );

#    print STDERR "login_cas:  gen_cookie " . (Dumper $c) . "\n";
    print CGI::header( -cookie => [$c] );
    return $coge_user;
}

sub parse_saml_response {
    my $response = $_[0];

    # mdb modified 4/4/13 for iPlant CAS update - XML::Simple doesn't support namespaces
    if( $response =~ m/saml1p:Success/ ) {
        my $ref = XMLin($response);
        print STDERR Dumper $ref, "\n";
        my ($user_id) =
          $ref->{'SOAP-ENV:Body'}->{'saml1p:Response'}->{'saml1:Assertion'}
          ->{'saml1:AttributeStatement'}->{'saml1:Subject'}
          ->{'saml1:NameIdentifier'};
        my @tmp =
          @{ $ref->{'SOAP-ENV:Body'}->{'saml1p:Response'}->{'saml1:Assertion'}
              ->{'saml1:AttributeStatement'}->{'saml1:Attribute'} };
        my %attr =
          map { $_->{'AttributeName'}, $_->{'saml1:AttributeValue'} }
          @{ $ref->{'SOAP-ENV:Body'}->{'saml1p:Response'}->{'saml1:Assertion'}
              ->{'saml1:AttributeStatement'}->{'saml1:Attribute'} };
        my ($user_lname) = $attr{lastName}->{content};
        my ($user_fname) = $attr{firstName}->{content};
        my ($user_email) = $attr{email}->{content};

	print STDERR "parse_saml_response: ".$user_id.'   '.$user_fname.'   '.$user_lname.'  '.$user_email."\n";
        return ( $user_id, $user_fname, $user_lname, $user_email );
    }
}

# mdb added 12/5/13 - Hackathon
sub parse_saml_response2 {
    my $response = $_[0];

	# mdb modified 4/4/13 for iPlant CAS update - XML::Simple doesn't support namespaces
    if ( $response =~ m/saml1?p:Success/ ) {
        my $ref = XMLin($response);
        print STDERR Dumper $ref, "\n";
        my ($user_id) =
          $ref->{'SOAP-ENV:Body'}->{'Response'}->{'Assertion'}
          ->{'AttributeStatement'}->{'Subject'}
          ->{'NameIdentifier'};
        my @tmp =
          @{ $ref->{'SOAP-ENV:Body'}->{'Response'}->{'Assertion'}
              ->{'AttributeStatement'}->{'Attribute'} };
        my %attr =
          map { $_->{'AttributeName'}, $_->{'AttributeValue'} }
          @{ $ref->{'SOAP-ENV:Body'}->{'Response'}->{'Assertion'}
              ->{'AttributeStatement'}->{'Attribute'} };
        my ($user_lname) = $attr{lastName};
        my ($user_fname) = $attr{firstName};
        my ($user_email) = $attr{email};

		print STDERR "parse_saml_response: ".$user_id.'   '.$user_fname.'   '.$user_lname.'  '.$user_email."\n";
        return ( $user_id, $user_fname, $user_lname, $user_email );
    }
}

# mdb added 3/27/15 for DE cas4 upgrade
# See http://jasig.github.io/cas/development/protocol/CAS-Protocol-Specification.html
sub login_cas4 {
    my ( $self, %opts ) = self_or_default(@_);
    my $cookie_name = $opts{cookie_name};
    my $ticket      = $opts{ticket};        # CAS ticket from iPlant
    my $this_url    = $opts{this_url};      # URL that CAS redirected to
    my $db          = $opts{db};            # db object
    my $server      = $opts{server};        # server -- this was added to get apache proxying to work with cas
    print STDERR "Web::login_cas4 ticket=$ticket this_url=$this_url\n";
    #print STDERR Dumper \%ENV, "\n";

    my $cas_url = get_defaults()->{CAS_URL};
    unless ($cas_url) {
        print STDERR "Web::login_cas4: error: CAS_URL not defined in configuration file\n";
        return;
    }
    
    # mdb: this is a hack to get our Apache proxy user sandboxes to work with CAS validation
    my $uri = $ENV{SCRIPT_NAME};
    $uri =~ s/^\///;
    my $page_url .= $ENV{HTTP_X_FORWARDED_HOST} . $uri;
    
    my $agent = new LWP::UserAgent;
    my $request = HTTP::Request->new( GET => $cas_url . '/serviceValidate?service=' . $page_url . '&ticket=' . $ticket );
    #$request_ua->content($request);
    #$request_ua->content_type("text/xml; charset=utf-8");
    my $response = $agent->request($request);
    #print STDERR "cas4 response: ", Dumper $response, "\n";
    my $result   = $response->content;
    print STDERR "cas result: ", Dumper $result, "\n";
    return unless $result;
    
    return;
}

sub ajax_func {
    return (
        read_log            => \&read_log,
        initialize_basefile => \&initialize_basefile,
    );
}

sub log_history {
    my %opts        = @_;
    my $db          = $opts{db};
    my $user_id     = $opts{user_id};
    my $workflow_id = $opts{workflow_id};
    my $page        = $opts{page};
    my $description = $opts{description};
    my $type        = $opts{type} || 0;
    my $link        = $opts{link};

    $type = 1 if ( $description and $description ne 'page access' );
    $user_id = 0 unless ( defined $user_id );
    $page =~ s/\.pl$//;    # remove trailing .pl extension
    return $db->resultset('Log')->create(
        {
            user_id     => $user_id,
            page        => $page,
            type        => $type,
            description => $description,
            link        => $link,
            workflow_id => $workflow_id
        }
    );
}

sub get_tiny_link {
    my %opts            = @_;
    my $url             = $opts{url};
#    my $db              = $opts{db};
#    my $user_id         = $opts{user_id};
#    my $page            = $opts{page};
#    my $log_msg         = $opts{log_msg};
#    my $disable_logging = $opts{disable_logging};    # flag

    $url =~ s/:::/__/g;

    #FIXME: Hack for tiny link service
    $url =~ s/&/;/g;

    my $request_url = "https://genomevolution.org/r/yourls-api.php?signature=d57f67d3d9&action=shorturl&format=simple&url=$url";

# mdb removed 1/8/14, issue 272
#    my $tiny = LWP::Simple::get($request_url);
#	 unless ($tiny) {
#        return "Unable to produce tiny url from server";
#    }
#    return $tiny;

    # mdb added 1/8/14, issue 272
    my $ua = new LWP::UserAgent;
    my $response_url;

	$ua->timeout(10);
	my $response = $ua->get($request_url);
	if ($response->is_success) {
        $response_url = $response->decoded_content;
	}
	else {
        cluck "Unable to produce tiny url from server falling back to url";
        return $url;
	}

    # check if the tiny link is a validate url
    return $url unless is_uri($response_url);

    return $response_url;

    # Log the page
# mdb removed 10/10/13 -- Move logging functionality out of this to fix issue 167
#    if ( $db and not $disable_logging ) {
#        $page =~ s/.pl$//;    # remove trailing .pl extension
#        log_history(
#            db          => $db,
#            user_id     => $user_id,
#            page        => $page,
#            description => ( $log_msg ? $log_msg : 'page access' ),
#            link        => $tiny
#        );
#    }
}

sub schedule_job {
    my %args = @_;
    my $job = $args{job};

    $job->update({
        start_time => \'current_timestamp',
        status     => 1,
    });
}

sub get_job {
    my %args = @_;
    my $job;
    my $tiny_link = $args{tiny_link};
    my $user_id   = $args{user_id};
    my $title     = $args{title};
    my $log_id    = $args{log_id};
    my $coge      = $args{db_object};

    $user_id = 0 unless defined($user_id);

    my $prev_submission = $coge->resultset('Job')->search(
        {
            user_id => $user_id,
            link    => $tiny_link
        }
    );

    if ( $prev_submission->count < 1 ) {
        $job = $coge->resultset('Job')->create(
            {
                link       => $tiny_link,
                page       => $title,
                process_id => getpid(),
                user_id    => $user_id,
                status     => 0,
            }
        );
    }
    else {
        $job = $prev_submission->next;
    }

    $job->update({ log_id => $log_id}) if $log_id && !$job->log_id;

    return $job;
}

sub write_log {
    $| = 1;
    my $message = shift;
    $message =~ /(.*)/xs;
    $message = $1;
    my $file = shift;
    return unless $file;
    open( OUT, ">>$file" ) || return;
    print OUT $message, "\n";
    close OUT;
}

sub read_log {
    my %args    = @_;
    my $logfile = $args{logfile};
    my $prog    = $args{prog};
    my $tempdir = $args{tempdir};
    $tempdir = $TEMPDIR unless $tempdir;
    return unless $logfile;
    $logfile .= ".log" unless $logfile =~ /log$/;
    unless ( $logfile =~ /^$tempdir/ ) {
        $logfile = "$prog/" . $logfile if $prog;
        $logfile = "$tempdir/" . $logfile;
    }
    return unless -r $logfile;
    my $str;
    open( IN, $logfile );
    while (<IN>) {
        $str .= $_;
    }
    close IN;
    return $str;
}

sub check_filename_taint {
    my $v = shift;
    return 1 unless $v;
    if ( $v =~ /^([A-Za-z0-9\-\.=\/_#\|]*)$/ ) {
        my $v1 = $1;
        return ($v1);
    }
    else {
        return (0);
    }
}

sub check_taint {
    my $v = shift;
    return 1 unless $v;
    if ( $v =~ /^([-\w\._=\s+\/,#\]\['"%\|]+)$/ ) {
        $v = $1;

        # $v now untainted
        return ( 1, $v );
    }
    else {

        # data should be thrown out
        carp "'$v' failed taint check\n";
        return (0);
    }
}

sub save_settings {
    my %opts    = @_;
    my $user    = $opts{user};
    my $user_id = $opts{user_id};
    my $page    = $opts{page};
    my $opts    = $opts{opts};
    my $coge    = $opts{coge};
    $opts = Dumper $opts unless $opts =~ /VAR1/;
    $user_id = $user->id if ( ref($user) =~ /User/i ) && !$user_id;

    unless ($user_id) {
        my ($user_obj) =
          $coge->resultset('User')->search( { user_name => $user } );
        $user_id = $user_obj->id if $user_obj;
    }
    return unless $user_id;

    #delete previous settings
    foreach my $item ( $coge->resultset('WebPreferences')
        ->search( { user_id => $user_id, page => $page } ) )
    {
        $item->delete;
    }
    my $item =
      $coge->resultset('WebPreferences')
      ->new( { user_id => $user_id, page => $page, options => $opts } );
    $item->insert;
    return $item;
}

sub load_settings {
    my %opts    = @_;
    my $user    = $opts{user};
    my $user_id = $opts{user_id};
    my $page    = $opts{page};
    my $coge    = $opts{coge};
    unless ($coge) {
        print STDERR "need a valid coge object";
        return;
    }
    $user_id = $user->id if ( ref($user) =~ /User/i ) && !$user_id;
    unless ($user_id) {
        my ($user_obj) =
          $coge->resultset('User')->search( { user_name => $user } );
        $user_id = $user_obj->id if $user_obj;
    }
    return {} unless $user_id;
    my ($item) =
      $coge->resultset('WebPreferences')
      ->search( { user_id => $user_id, page => $page } );
    return {} unless $item;
    my $prefs;
    my $opts = $item->options if $item;
    return {} unless $opts;
    $opts =~ s/VAR1/prefs/;
    eval $opts;
    return $prefs;
}

sub reset_settings {
    my %opts    = @_;
    my $user    = $opts{user};
    my $user_id = $opts{user_id};
    my $page    = $opts{page};
    my $coge    = $opts{coge};
    $user_id = $user->id if ( ref($user) =~ /User/i ) && !$user_id;
    unless ($user_id) {
        my ($user_obj) =
          $coge->resultset('User')->search( { user_name => $user } );
        $user_id = $user_obj->id if $user_obj;
    }
    return unless $user_id;
    my ($item) =
      $coge->resultset('WebPreferences')
      ->search( { user_id => $user_id, page => $page } );
    $item->delete;
}

sub initialize_basefile {
    my ( $self, %opts ) = self_or_default(@_);
    my $basename    = $opts{basename};
    my $prog        = $opts{prog};
    my $return_name = $opts{return_name};
    my $tempdir     = $opts{tempdir} || $TEMPDIR;
    $tempdir .= "/" . $prog if $prog;
    if ($basename) {

        #print STDERR "Have basename: $basename\n";
        ($basename) = $basename =~ /([^\/].*$)/;
        my ( $x, $cleanname ) = check_taint($basename);
        $self->basefilename($cleanname);
        my $basefile = $tempdir . "/" . $cleanname;
        $basefile =~ s/\/\/+/\//g;
        $self->basefile($basefile);
        $self->logfile( $self->basefile . ".log" );
        $self->sqlitefile( $self->basefile . ".sqlite" );
    }
    else {
        mkdir "$tempdir", 0777 unless -d "$tempdir";
        $prog = "CoGe" unless $prog;
        my $file = new File::Temp(
            TEMPLATE => $prog . '_XXXXXXXX',
            DIR      => "$tempdir/",

            #SUFFIX=>'.png',
            UNLINK => 1
        );
        $self->basefile( $file->filename );
        $self->logfile( $self->basefile . ".log" );
        $self->sqlitefile( $self->basefile . ".sqlite" );
        $self->basefilename( $file->filename =~ /([^\/]*$)/ );
    }

    #    print STDERR "Basename: ",$self->basefilename,"\n";
    #    print STDERR "sqlitefile: ",$self->sqlitefile,"\n";
    #    print STDERR "Basefile: ",$self->basefile,"\n";

    if ( -r $self->logfile && !$basename ) {
        print STDERR "in Web.pm sub initialize_basefile.  Logfile "
          . $self->logfile
          . " already exist.  Possible problem.  Regenerating basefile.\n";
        return $self->initialize_basefile(%opts);
    }
    elsif ($return_name) {
        return $self->basefilename;
    }
    else { return $self; }
}

sub gzip {
    my ( $self, $file ) = self_or_default(@_);
    my $GZIP = get_defaults()->{GZIP};
    return $file unless $file;
    return $file . ".gz" if -r "$file.gz";
    return $file unless -r $file;
    return $file if $file =~ /\.gz$/;
    `$GZIP $file` if -r $file;
    my $tmp = $file . ".gz";
    return -r $tmp ? $tmp : $file;
}

sub gunzip {
    my ( $self, $file, $debug ) = self_or_default(@_);
    my $GUNZIP = get_defaults()->{GUNZIP};
    unless ($GUNZIP) {
        print STDERR "ERROR: in gunzip!  gunzip binary is not specified!\n"
          if $debug;
    }
    print STDERR "Debugging sub gunzip\n" if $debug;
    print STDERR "\t", $file, "\n" if $debug;
    $file .= ".gz" if -r $file . ".gz";
    print STDERR "\t", $file, "!\n" if $debug;
    if ( -r $file && $file =~ /\.gz/ ) {
        print STDERR "\t", "Running $GUNZIP $file\n";
        `$GUNZIP $file`;
    }
    my $tmp = $file;
    $tmp =~ s/\.gz$//;
    my $return = -r $tmp ? $tmp : $file;
    print STDERR "\t", "returning $return\n" if $debug;
    return $return;
}

sub send_email {
    my %opts    = @_;
    my $from    = $opts{from};
    my $to      = $opts{to};
    my $subject = $opts{subject};
    my $body    = $opts{body};
    return unless ($from and $to and $subject);

    print STDERR "Sending email: from=$from to=$to subject=$subject\nbody:\n$body\n";

    my $mailer = Mail::Mailer->new("sendmail");
    $mailer->open(
        {
            From    => $from,
            To      => $to,
            Subject => $subject,
        }
    ) or die "Can't open: $!\n";

    print $mailer $body;
    $mailer->close();
}

sub url_for {
    my ($path, %params) = @_;

    # Error if CONFIG not set
    croak "CONFIG was not found." unless $CONF;

    my $SERVER = $CONF->{SERVER};
    my $BASE_URL = $CONF->{URL};

    # Error if SERVER not found
    croak "SERVER option not found in CONFIG." unless $SERVER;

    # Configures the default scheme
    my $scheme = $CONF->{SECURE} ? "https://" : "http://";

    # SERVER may override the default scheme
    if ($SERVER =~ /(?<scheme>https?:\/{2})/) {
        $scheme = $+{scheme};
    }

    # Strip leading /
    $path =~ s/^\///;

    # Strip leading and trailing /
    $BASE_URL =~ s/^\///;
    $BASE_URL =~ s/\/$//;

    # Strip BASE URL from SERVER
    $SERVER =~ s/$BASE_URL//i;

    # Strip scheme and /
    $SERVER =~ s/\/*$//;
    $SERVER =~ s/^https?:\/{2}//;
    $SERVER =~ s/\/$//;

    # Build up parts and ignore BASE_URL if not set
    my @parts = (length $BASE_URL) ? ($SERVER, $BASE_URL, $path)
                                   : ($SERVER, $path);

    # Build query string from params
    my ($query_string, @pairs) = ("", ());

    foreach my $key (sort keys %params) {
        push @pairs, $key . "=" . $params{$key};
    }

    $query_string = "?" . join("&", @pairs) if @pairs;

    return $scheme . join("/", @parts) . $query_string;;
}

1;
