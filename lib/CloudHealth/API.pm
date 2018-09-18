package CloudHealth::API::Error;
  use Moo;
  use Types::Standard qw/Str/;
  extends 'Throwable::Error';

  has type => (is => 'ro', isa => Str, required => 1);
  has detail => (is => 'ro');

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
  use Types::Standard qw/Maybe Str Bool/;

  has api_key => (
    is => 'ro',
    isa => Maybe[Str],
    required => 1,
    default => sub { $ENV{ CLOUDHEALTH_APIKEY } }
  );

  has is_set => (
    is => 'ro',
    isa => Bool,
    lazy => 1,
    default => sub {
      my $self = shift;
      return defined $self->api_key
    }
  );

package CloudHealth::Net::HTTPRequest;
  use Moo;
  use Types::Standard qw/Str HashRef/;

  has method => (is => 'rw', isa => Str);
  has url => (is => 'rw', isa => Str);
  has headers => (is => 'rw', isa => HashRef);
  has parameters => (is => 'rw', isa => HashRef);
  has content => (is => 'rw', isa => Str);

package CloudHealth::Net::HTTPResponse;
  use Moo;
  use Types::Standard qw/Str Int/;

  has content => (is => 'ro', isa => Str);
  has status => (is => 'ro', isa => Int);

package CloudHealth::API::CallObjectFormer;
  use Moo;
  use HTTP::Tiny;
  use JSON::MaybeXS;

  has _json => (is => 'ro', default => sub { JSON::MaybeXS->new });

  sub callinfo_class {
    my ($self, $call) = @_;
    "CloudHealth::API::Call::$call"
  }

  sub params2request {
    my ($self, $call, $creds, $user_params) = @_;

    my $call_object = eval { $self->callinfo_class($call)->new(@$user_params) };
    if ($@) {
      my $msg = $@;
      CloudHealth::API::Error->throw(
        type => 'InvalidParameters',
        message => "Error in parameters to method $call",
        detail => $msg,
      );
    }

    my $body_struct;
    if ($call_object->can('_body_params')) {
      $body_struct = {};
      foreach my $param (@{ $call_object->_body_params }) {
        my $key = $param->{ name };
        my $value = $call_object->$key;
        next if (not defined $value);

        my $location = defined $param->{ location } ? $param->{ location } : $key;
        $body_struct->{ $location } = $value;
      }
    }

    CloudHealth::API::Error->throw(
      type => 'NoCredentials',
      message => 'Cannot find credentials for the request'
    ) if (not $creds->is_set);

    my $params = {
      api_key => $creds->api_key,
    };
    foreach my $param (@{ $call_object->_query_params }) {
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
      (defined $body_struct) ? ('Content-Type' => 'application/json') : (),
      Accept => 'application/json',
    });
    $req->content($self->_json->encode($body_struct)) if (defined $body_struct);

    return $req;
  }
package CloudHealth::API::Call::EnableAWSAccount;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool Dict Optional ArrayRef/;

  has name => (is => 'ro', isa => Str);
  has authentication => (
    is => 'ro', required => 1,
    isa => Dict[
      protocol => Str,
      access_key => Optional[Str],
      secret_key => Optional[Str],
      assume_role_arn => Optional[Str],
      assume_role_external_id => Optional[Str],
    ]
  );
  has billing => (is => 'ro', isa => Dict[bucket => Str]);
  has cloudtrail => (
    is => 'ro',
    isa => Dict[
      enabled => Bool,
      bucket => Str,
      prefix => Optional[Str]
    ]
  );
  has aws_config => (
    is => 'ro',
    isa => Dict[
      enabled => Bool,
      bucket => Str,
      prefix => Optional[Str]
    ]
  );
  has cloudwatch => (
    is => 'ro',
    isa => Dict[enabled => Bool]
  );
  has tags => (
    is => 'ro',
    isa => ArrayRef[Dict[key => Str, value => Str]]
  );
  has hide_public_fields => (is => 'ro', isa => Bool);
  has region => (is => 'ro', isa => Str);

  sub _body_params { [
    { name => 'name' },
    { name => 'authentication' },
    { name => 'billing' },
    { name => 'cloudtrail' },
    { name => 'aws_config' },
    { name => 'cloudwatch' },
    { name => 'tags' },
    { name => 'hide_public_fields' },
    { name => 'region' },
  ] }
  sub _query_params { [ ] }
  sub _url_params { [ ] }
  sub _method { 'POST' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts' }

package CloudHealth::API::Call::AWSAccounts;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int/;

  has page => (is => 'ro', isa => Int);
  has per_page => (is => 'ro', isa => Int);

  sub _query_params { [
    { name => 'page' },
    { name => 'per_page' },
  ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts' }

package CloudHealth::API::Call::SingleAWSAccount;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int/;

  has id => (is => 'ro', isa => Int, required => 1);

  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'id' },
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts/:id' }

package CloudHealth::API::Call::UpdateExistingAWSAccount;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool Dict Optional ArrayRef/;

  has id => (is => 'ro', isa => Str, required => 1);

  has name => (is => 'ro', isa => Str);
  has authentication => (
    is => 'ro', required => 1,
    isa => Dict[
      protocol => Str,
      access_key => Optional[Str],
      secret_key => Optional[Str],
      assume_role_arn => Optional[Str],
      assume_role_external_id => Optional[Str],
    ]
  );
  has billing => (is => 'ro', isa => Dict[bucket => Str]);
  has cloudtrail => (
    is => 'ro',
    isa => Dict[
      enabled => Bool,
      bucket => Str,
      prefix => Optional[Str]
    ]
  );
  has aws_config => (
    is => 'ro',
    isa => Dict[
      enabled => Bool,
      bucket => Str,
      prefix => Optional[Str]
    ]
  );
  has cloudwatch => (
    is => 'ro',
    isa => Dict[enabled => Bool]
  );
  has tags => (
    is => 'ro',
    isa => ArrayRef[Dict[key => Str, value => Str]]
  );
  has hide_public_fields => (is => 'ro', isa => Bool);
  has region => (is => 'ro', isa => Str);

  sub _body_params { [
    { name => 'name' },
    { name => 'authentication' },
    { name => 'billing' },
    { name => 'cloudtrail' },
    { name => 'aws_config' },
    { name => 'cloudwatch' },
    { name => 'tags' },
    { name => 'hide_public_fields' },
    { name => 'region' },
  ] }
  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'id' },
  ] }
  sub _method { 'PUT' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts/:id' }


package CloudHealth::API::Call::DeleteAWSAccount;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int/;

  has id => (is => 'ro', isa => Int, required => 1);

  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'id' },
  ] }
  sub _method { 'DELETE' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts/:id' }

package CloudHealth::API::Call::GetExternalID;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  has id => (is => 'ro', isa => Str, required => 1);

  sub _query_params { [ ] }
  sub _url_params { [  
    { name => 'id' }
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts/:id/generate_external_id' }

package CloudHealth::API::Call::RetrieveAllPerspectives;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  has active_only => (is => 'ro', isa => Bool);

  sub _query_params { [ 
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

  sub _query_params { [ 
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

  sub _query_params { [ ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/olap_reports' }

package CloudHealth::API::Call::ListReportsOfSpecificType;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  has type => (is => 'ro', isa => Str, required => 1);

  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'type', location => 'report-type' }    
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/olap_reports/:report-type' }

package CloudHealth::API::Call::ListOfQueryableAssets;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  sub _query_params { [ ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/api' }

package CloudHealth::API::Call::AttributesOfSingleAsset;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int Bool/;

  has asset => (is => 'ro', isa => Str, required => 1);

  sub _query_params { [ ] }
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

  sub _query_params { [
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

  sub _query_params { [
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
  use Types::Standard qw/Dict Str ArrayRef Int/;

  our $tags_cons = Dict[key => Str, value => Str];
  our $tag_group_cons = Dict[asset_type => Str, ids => ArrayRef[Int], tags => ArrayRef[$tags_cons]];
  has tag_groups => (is => 'ro', isa => ArrayRef[$tag_group_cons], required => 1);

  sub _body_params { [
    { name => 'tag_groups' },
  ] }
  sub _query_params { [ ] }
  sub _url_params { [ ] }
  sub _method { 'POST' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/custom_tags' }

package CloudHealth::API::Call::CreatePartnerCustomer;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int Str Dict Maybe ArrayRef/;

  has name => (is => 'ro', isa => Str, required => 1);
  has address => (is => 'ro', isa => Dict[street1 => Str, street2 => Str, city => Str, state => Str, zipcode => Int, country => Str], required => 1);
  has classification => (is => 'ro', isa => Str);
  has trial_expiration_date => (is => 'ro', isa => Str);
  has billing_contact => (is => 'ro', isa => Str);
  has partner_billing_configuration => (is => 'ro', isa => Dict[enabled => Str, folder => Maybe[Str]]);
  has tags => (is => 'ro', isa => ArrayRef[Dict[key => Str, value => Str]]);

  sub _body_params { [
    { name => 'name' },
    { name => 'address' },
    { name => 'classification' },
    { name => 'trial_expiration_date' },
    { name => 'billing_contact' },
    { name => 'partner_billing_configuration' },
    { name => 'tags' },
  ] }
  sub _query_params { [ ] }
  sub _url_params { [ ] }
  sub _method { 'POST' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/customers' }

package CloudHealth::API::Call::ModifyExistingCustomer;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int Str Dict Maybe ArrayRef/;

  has customer_id => (is => 'ro', isa => Int, required => 1);

  has name => (is => 'ro', isa => Str);
  has address => (is => 'ro', isa => Dict[street1 => Str, street2 => Str, city => Str, state => Str, zipcode => Int, country => Str]);
  has classification => (is => 'ro', isa => Str);
  has trial_expiration_date => (is => 'ro', isa => Str);
  has billing_contact => (is => 'ro', isa => Str);
  has partner_billing_configuration => (is => 'ro', isa => Dict[enabled => Str, folder => Maybe[Str]]);
  has tags => (is => 'ro', isa => ArrayRef[Dict[key => Str, value => Str]]);

  sub _body_params { [
    { name => 'name' },
    { name => 'address' },
    { name => 'classification' },
    { name => 'trial_expiration_date' },
    { name => 'billing_contact' },
    { name => 'partner_billing_configuration' },
    { name => 'tags' },
  ] }
  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'customer_id' }, 
  ] }
  sub _method { 'PUT' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/customers/:customer_id' }

package CloudHealth::API::Call::DeleteExistingCustomer;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int/;

  has customer_id => (is => 'ro', isa => Int, required => 1);

  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'customer_id' },
  ] }
  sub _method { 'DELETE' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/customers/:customer_id' }

package CloudHealth::API::Call::GetSingleCustomer;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int/;

  has customer_id => (is => 'ro', isa => Int, required => 1);

  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'customer_id' },
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/customers/:customer_id' }

package CloudHealth::API::Call::GetAllCustomers;
  use Moo;
  use MooX::StrictConstructor;

  sub _query_params { [ ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/customers' }

package CloudHealth::API::Call::StatementForSingleCustomer;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int/;

  has id => (is => 'ro', isa => Int, required => 1);

  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'id' },  
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/customer_statements/:id' }

package CloudHealth::API::Call::StatementsForAllCustomers;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int/;

  has page => (is => 'ro', isa => Int);
  has per_page => (is => 'ro', isa => Int);
 
  sub _query_params { [
    { name => 'page' },
    { name => 'per_page' },  
  ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/customer_statements' }

package CloudHealth::API::Caller;
  use Moo;
  use HTTP::Tiny;

  has ua => (is => 'ro', default => sub {
    HTTP::Tiny->new(
      agent => 'CloudHealth::API Perl Client ' . $CloudHealth::API::VERSION,
    );
  });

  sub call {
    my ($self, $req) = @_;

    my $res = $self->ua->request(
      $req->method,
      $req->url,
      {
        headers => $req->headers,
        (defined $req->content) ? (content => $req->content) : (),
      }
    );

    return CloudHealth::Net::HTTPResponse->new(
       status => $res->{ status },
       (defined $res->{ content })?( content => $res->{ content } ) : (),
    );
  }

package CloudHealth::API::ResultParser;
  use Moo;
  use JSON::MaybeXS;

  has parser => (is => 'ro', default => sub { JSON::MaybeXS->new });

  sub result2return {
    my ($self, $response) = @_;

    if ($response->status >= 400) {
      return $self->process_error($response);
    } else {
      return 1 if (not defined $response->content);
      return $self->process_response($response);
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

    my $message;
    if (defined $struct->{ error }) {
      $message = $struct->{ error };
    } elsif ($struct->{ errors } and ref($struct->{ errors }) eq 'ARRAY') {
      $message = join ',', @{ $struct->{ errors } };
    } else {
      $message = 'No message';
    }

    CloudHealth::API::RemoteError->throw(
      status => $response->status,
      message => $message,
    )
  }
package CloudHealth::API;
  use Moo;
  use Types::Standard qw/HasMethods/;

  our $VERSION = '0.01';

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

  sub method_classification {
    {
      aws_accounts => [ qw/EnableAWSAccount AWSAccounts SingleAWSAccount 
                           UpdateExistingAWSAccount DeleteAWSAccount GetExternalID/ ],
      perspectives => [ qw/RetrieveAllPerspectives RetrievePerspectiveSchema CreatePerspectiveSchema
                           UpdatePerspectiveSchema DeletePerspectiveSchema/ ],
      reports      => [ qw/ListQueryableReports ListReportsOfSpecificType DataForStandardReport 
                           DataForCustomReport ReportDimensionsAndMeasures/ ],
      assets       => [ qw/ListOfQueryableAssets AttributesOfSingleAsset SearchForAssets/ ],
      metrics      => [ qw/MetricsForSingleAsset UploadMetricsForSingleAsset/ ],
      tags         => [ qw/UpdateTagsForSingleAsset/ ],
      partner      => [ qw/SpecificCustomerReport AssetsForSpecificCustomer CreatePartnerCustomer 
                           ModifyExistingCustomer DeleteExistingCustomer GetSingleCustomer GetAllCustomers
                           StatementForSingleCustomer StatementsForAllCustomers
                           CreateAWSAccountAssignment ReadAllAWSAccountAssignments 
                           ReadSingleAWSAccountAssignment UpdateAWSAccountAssignment 
                           DeleteAWSAccountAssignment/ ],
      gov_cloud    => [ qw/ConnectGovCloudCommercialAccountToGovCloudAssetAccount
                           ListAllGovCloudLinkagesOwnedByCurrentCustomer
                           DetailsOfSingleGovCloudLinkage UpdateSingleGovCloudLinkage
                           UnderstandFormatOfGovCloudLinkagePayload/ ],
    }
  }

  sub EnableAWSAccount {
    my $self = shift;
    $self->_invoke('EnableAWSAccount', [ @_ ]);
  }
  sub AWSAccounts {
    my $self = shift;
    $self->_invoke('AWSAccounts', [ @_ ]);
  }
  sub SingleAWSAccount {
    my $self = shift;
    $self->_invoke('SingleAWSAccount', [ @_ ]);
  }
  sub UpdateExistingAWSAccount {
    my $self = shift;
    $self->_invoke('UpdateExistingAWSAccount', [ @_ ]);
  }
  sub DeleteAWSAccount {
    my $self = shift;
    $self->_invoke('DeleteAWSAccount', [ @_ ]);
  }
  sub GetExternalID {
    my $self = shift;
    $self->_invoke('GetExternalID', [ @_ ]); 
  }

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
  sub CreatePartnerCustomer {
    my $self = shift;
    $self->_invoke('CreatePartnerCustomer', [ @_ ]);  
  }
  sub ModifyExistingCustomer {
    my $self = shift;
    $self->_invoke('ModifyExistingCustomer', [ @_ ]);  
  }
  sub DeleteExistingCustomer {
    my $self = shift;
    $self->_invoke('DeleteExistingCustomer', [ @_ ]);  
  }
  sub GetSingleCustomer {
    my $self = shift;
    $self->_invoke('GetSingleCustomer', [ @_ ]);
  }
  sub GetAllCustomers {
    my $self = shift;
    $self->_invoke('GetAllCustomers', [ @_ ]); 
  }
  sub StatementForSingleCustomer {
    my $self = shift;
    $self->_invoke('StatementForSingleCustomer', [ @_ ]);
  }
  sub StatementsForAllCustomers {
    my $self = shift;
    $self->_invoke('StatementsForAllCustomers', [ @_ ]);
  }

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
