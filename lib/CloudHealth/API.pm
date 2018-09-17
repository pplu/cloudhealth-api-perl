package CloudHealth::API::Error;
  use Moo;
  use Types::Standard qw/Str/;
  extends 'Throwable::Error';

  has type => (is => 'ro', isa => Str, required => 1);
  has detail => (is => 'ro', isa => Str);

  sub header {
    my $self = shift;
    return sprintf "Exception with type: %s: %s", $self->type, $self->message;
  }

  sub as_string {
    my $self = shift;
    if (defined $self->detail) {
      return sprintf "%s\nDetail: %s", $self->header, $self->detail;
    } else {
      return $self->header;
    }
  }

package CloudHealth::API::RemoteError;
  use Moo;
  use Types::Standard qw/Int/;
  extends 'CloudHealth::API::Error';

  has '+type' => (default => sub { 'Remote' });
  has status => (is => 'ro', isa => Int, required => 1);

  around header => sub {
    my ($orig, $self) = @_;
    my $orig_message = $self->$orig;
    sprintf "%s with HTTP status %d", $orig_message, $self->status;
  };

package CloudHealth::API::Credentials;
  use Moo;
  use Types::Standard qw/Str/;

  has api_key => (
    is => 'ro',
    isa => Str,
    required => 1,
    default => sub { $ENV{ CLOUDHEALTH_APIKEY } }
  );

package CloudHealth::Net::HTTPRequest;
  use Moo;
  use Types::Standard qw/Str HashRef/;

  has method => (is => 'rw', isa => Str);
  has url => (is => 'rw', isa => Str);
  has headers => (is => 'rw', isa => HashRef);
  has parameters => (is => 'rw', isa => HashRef);

package CloudHealth::Net::HTTPResponse;
  use Moo;
  use Types::Standard qw/Str Int/;

  has content => (is => 'ro', isa => Str);
  has status => (is => 'ro', isa => Int);

package CloudHealth::API::CallObjectFormer;
  use Moo;
  use HTTP::Tiny;

  sub params2request {
    my ($self, $call, $creds, $user_params) = @_;

    my $call_object = eval { "CloudHealth::API::Call::$call"->new(@$user_params) };
    if ($@) {
      my $msg = $@;
      CloudHealth::API::Error->throw(
        type => 'InvalidParameters',
        message => "Error in parameters to method $call",
        detail => $msg,
      );
    }

    my $params = {
      api_key => $creds->api_key,
    };
    foreach my $param (@{ $call_object->_parameters }) {
      my $key = $param->{ name };
      my $value = $call_object->$key;
      next if (not defined $value);

      my $location = defined $param->{ location } ? $param->{ location } : $key;
      $params->{ $location } = $value;
    }

    my $url_params = {};
    foreach my $param (@{ $call_object->_url_params }) {
      my $key = $param->{ name };
      my $value = $call_object->$key;
      next if (not defined $value);

      my $location = defined $param->{ location } ? $param->{ location } : $key;
      $url_params->{ $location } = $value;
    }
    my $url = $call_object->_url;
    $url =~ s/\:([a-z0-9_-]+)/$url_params->{ $1 }/ge;

    my $qstring = HTTP::Tiny->www_form_urlencode($params);
    my $req = CloudHealth::Net::HTTPRequest->new;
    $req->method($call_object->_method);
    $req->url(
      "$url?$qstring",
    );
    $req->headers({
      Accept => 'application/json',
    });

    return $req;
  }

package CloudHealth::API::Call::RetrieveAllPerspectives;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  has active_only => (is => 'ro', isa => Bool);

  sub _parameters { [ 
    { name => 'active_only' }
  ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/perspective_schemas' }

package CloudHealth::API::Call::RetrievePerspectiveSchema;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  has include_version => (is => 'ro', isa => Bool);
  has perspective_id => (is => 'ro', isa => Str, required => 1);

  sub _parameters { [ 
    { name => 'include_version' },
  ] }
  sub _url_params { [ 
    { name => 'perspective_id', location => 'perspective-id' }
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/perspective_schemas/:perspective-id' }

package CloudHealth::API::Call::ListQueryableReports;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  sub _parameters { [ ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/olap_reports' }

package CloudHealth::API::Call::ListReportsOfSpecificType;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  has type => (is => 'ro', isa => Str, required => 1);

  sub _parameters { [ ] }
  sub _url_params { [
    { name => 'type', location => 'report-type' }    
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/olap_reports/:report-type' }

package CloudHealth::API::Call::ListOfQueryableAssets;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  sub _parameters { [ ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/api' }

package CloudHealth::API::Call::AttributesOfSingleAsset;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  has asset => (is => 'ro', isa => Str, required => 1);

  sub _parameters { [ ] }
  sub _url_params { [ 
    { name => 'asset' }
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/api/:asset' }

package CloudHealth::API::Call::SearchForAssets;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  has name => (is => 'ro', isa => Str, required => 1);
  has query => (is => 'ro', isa => Str, required => 1);
  has include => (is => 'ro', isa => Str);
  has api_version => (is => 'ro', isa => Int, default => 2);
  has fields => (is => 'ro', isa => Str);
  has page => (is => 'ro', isa => Int);
  has per_page => (is => 'ro', isa => Int);
  has is_active => (is => 'ro', isa => Bool);

  sub _parameters { [
    { name => 'name' },
    { name => 'query' },
    { name => 'include' },  
    { name => 'api_version' },  
    { name => 'fields' },  
    { name => 'page' },  
    { name => 'per_page' },  
    { name => 'is_active' },  
  ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/api/search' }

package CloudHealth::API::Call::MetricsForSingleAsset;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  has asset => (is => 'ro', isa => Str, required => 1);
  has granularity => (is => 'ro', isa => Str);
  has from => (is => 'ro', isa => Str);
  has to => (is => 'ro', isa => Str);
  has time_range => (is => 'ro', isa => Str);
  has page => (is => 'ro', isa => Int);
  has per_page => (is => 'ro', isa => Int);

  sub _parameters { [
    { name => 'asset' },
    { name => 'granularity' },
    { name => 'from' },
    { name => 'to' },
    { name => 'time_range' },
    { name => 'page' },
    { name => 'per_page' },
  ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/metrics' }

package CloudHealth::API::Call::UpdateTagsForSingleAsset;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/HashRef/;

  has document => (is => 'ro', isa => HashRef, required => 1);

  sub _parameters { [ ] }
  sub _url_params { [ ] }
  sub _method { 'POST' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/custom_tags' }


package CloudHealth::API::Caller;
  use Moo;
  use HTTP::Tiny;

  has ua => (is => 'ro', default => sub { HTTP::Tiny->new });

  sub call {
    my ($self, $req) = @_;

    my $res = $self->ua->request(
      $req->method,
      $req->url,
      {
        headers => $req->headers,
      }
    );

    return CloudHealth::Net::HTTPResponse->new(
       status => $res->{ status },
       content => $res->{ content },
    );
  }

package CloudHealth::API::ResultParser;
  use Moo;
  use JSON::MaybeXS;

  has parser => (is => 'ro', default => sub { JSON::MaybeXS->new });

  sub result2return {
    my ($self, $response) = @_;

    if ($response->status == 200) {
      return $self->process_response($response);
    } else {
      return $self->process_error($response);
    } 
  }

  sub process_response {
    my ($self, $response) = @_;
    
    my $struct = eval {
      $self->parser->decode($response->content);
    };
    CloudHealth::API::Error->throw(
      type => 'UnparseableResponse',
      message => 'Can\'t parse response ' . $response->content . ' with error ' . $@
    ) if ($@);

    return $struct;
  }

  # Process a response following http://apidocs.cloudhealthtech.com/#documentation_error-codes
  sub process_error {
    my ($self, $response) = @_;

    my $struct = eval {
      $self->parser->decode($response->content);
    };

    CloudHealth::API::Error->throw(
      type => 'UnparseableResponse',
      message => 'Can\'t parse JSON content',
      detail => $response->content,
    ) if ($@);

    CloudHealth::API::RemoteError->throw(
      status => $response->status,
      message => ($struct->{ error } // 'No message'),
    )
  }
package CloudHealth::API;
  use Moo;
  use Types::Standard qw/HasMethods/;

  has call_former => (is => 'ro', isa => HasMethods['params2request'], default => sub {
    CloudHealth::API::CallObjectFormer->new;  
  });
  has credentials => (is => 'ro', isa => HasMethods['api_key'], default => sub {
    CloudHealth::API::Credentials->new;
  });
  has io => (is => 'ro', isa => HasMethods['call'], default => sub {
    CloudHealth::API::Caller->new;
  });
  has result_parser => (is => 'ro', isa => HasMethods['result2return'], default => sub {
    CloudHealth::API::ResultParser->new
  });

  sub _invoke {
    my ($self, $method, $params) = @_;
    my $req = $self->call_former->params2request($method, $self->credentials, $params);
    my $result = $self->io->call($req);
    return $self->result_parser->result2return($result);
  }

  sub EnableAWSAccount { die "TODO" }
  sub AWSAccounts { die "TODO" }
  sub SingleAWSAccount { die "TODO" }
  sub UpdateExistingAWSAccount { die "TODO" }
  sub DeleteAWSAccount { die "TODO" }
  sub GetExternalID { die "TODO" }

  sub RetrieveAllPerspectives {
    my $self = shift;
    $self->_invoke('RetrieveAllPerspectives', [ @_ ]);
  }

  sub RetrievePerspectiveSchema {
    my $self = shift;
    $self->_invoke('RetrievePerspectiveSchema', [ @_ ]);
  }

  sub CreatePerspectiveSchema { die "TODO" }
  sub UpdatePerspectiveSchema { die "TODO" }
  sub DeletePerspectiveSchema { die "TODO" }

  sub ListQueryableReports {
    my $self = shift;
    $self->_invoke('ListQueryableReports', [ @_ ]);
  }

  sub ListReportsOfSpecificType {
    my $self = shift;
    $self->_invoke('ListReportsOfSpecificType', [ @_ ]);
  }

  sub DataForStandardReport { die "TODO" }
  sub DataForCustomReport { die "TODO" }
  sub ReportDimensionsAndMeasures { die "TODO" }

  sub ListOfQueryableAssets {
    my $self = shift;
    $self->_invoke('ListOfQueryableAssets', [ @_ ]);
  }

  sub AttributesOfSingleAsset {
    my $self = shift;
    $self->_invoke('AttributesOfSingleAsset', [ @_ ]);
  }

  sub SearchForAssets {
    my $self = shift;
    $self->_invoke('SearchForAssets', [ @_ ]);
  }

  sub MetricsForSingleAsset {
    my $self = shift;
    $self->_invoke('MetricsForSingleAsset', [ @_ ]);
  }

  sub UploadMetricsForSingleAsset { die "TODO" }

  sub UpdateTagsForSingleAsset {
    my $self = shift;
    $self->_invoke('UpdateTagsForSingleAsset', [ @_ ]);
  }

  sub SpecificCustomerReport { die "TODO" }
  sub AssetsForSpecificCustomer { die "TODO" }
  sub CreatePartnerCustomer { die "TODO" }
  sub ModifyExistingCustomer { die "TODO" }
  sub DeleteExistingCustomer { die "TODO" }
  sub GetSingleCustomer { die "TODO" }
  sub GetAllCustomers { die "TODO" }
  sub StatementForSingleCustomer { die "TODO" }
  sub StatementsForAllCustomers { die "TODO" }

  sub ConnectGovCloudCommercialAccountToGovCloudAssetAccount { die "TODO" }
  sub ListAllGovCloudLinkagesOwnedByCurrentCustomer { die "TODO" }
  sub DetailsOfSingleGovCloudLinkage { die "TODO" }
  sub UpdateSingleGovCloudLinkage { die "TODO" }
  sub UnderstandFormatOfGovCloudLinkagePayload { die "TODO" }
  
  sub CreateAWSAccountAssignment { die "TODO" }
  sub ReadAllAWSAccountAssignments { die "TODO" }
  sub ReadSingleAWSAccountAssignment { die "TODO" }
  sub UpdateAWSAccountAssignment { die "TODO" }
  sub DeleteAWSAccountAssignment { die "TODO" }

1;
