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

  sub call_metadata {
    my ($self, $call) = @_;
    my $call_class = $self->callinfo_class($call);
    return {
      query_params => $call_class->_query_params,
      body_params => ($call_class->can('_body_params') ? $call_class->_body_params : undef),
      url_params => $call_class->_url_params,
      url => $call_class->_url,
      method => $call_class->_method,
    }
  }

  sub params2request {
    my ($self, $call, $creds, $user_params) = @_;
    $user_params = { @$user_params };

    my $call_metadata = $self->call_metadata($call);

      #CloudHealth::API::Error->throw(
      #  type => 'InvalidParameters',
      #  message => "Error in parameters to method $call",
      #  detail => $msg,
      #);

    my $body_struct;
    if (defined $call_metadata->{ body_params }) {
      $body_struct = {};
      foreach my $param (@{ $call_metadata->{ body_params } }) {
        my $key = $param->{ name };
        my $value = $user_params->{ $key };

        if (not defined $param->{ required } or $param->{ required } == 0) {
          next if (not defined $value);
        } else {
          CloudHealth::API::Error->throw(
            type => 'InvalidParameters',
            message => "$key is required"
          ) if (not defined $value);
        }

        if (my $msg = $param->{ isa }->validate($value)) {
          CloudHealth::API::Error->throw(
            type => 'InvalidParameters',
            message => $msg,
          );
        }

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
    foreach my $param (@{ $call_metadata->{ query_params } }) {
      my $key = $param->{ name };
      my $value = $user_params->{ $key };
      next if (not defined $value);

      my $location = defined $param->{ location } ? $param->{ location } : $key;
      $params->{ $location } = $value;
    }

    my $url_params = {};
    foreach my $param (@{ $call_metadata->{ url_params } }) {
      my $key = $param->{ name };
      my $value = $user_params->{ $key };
      next if (not defined $value);

      my $location = defined $param->{ location } ? $param->{ location } : $key;
      $url_params->{ $location } = $value;
    }
    my $url = $call_metadata->{ url };
    $url =~ s/\:([a-z0-9_-]+)/$url_params->{ $1 }/ge;

    my $qstring = HTTP::Tiny->www_form_urlencode($params);
    my $req = CloudHealth::Net::HTTPRequest->new;
    $req->method($call_metadata->{ method });
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

  our $authentication_cons = Dict[
      protocol => Str,
      access_key => Optional[Str],
      secret_key => Optional[Str],
      assume_role_arn => Optional[Str],
      assume_role_external_id => Optional[Str],
    ];
  our $billing_cons = Dict[bucket => Str];
  our $cloudtrail_cons = Dict[
    enabled => Bool,
    bucket => Str,
    prefix => Optional[Str]
  ];
  our $aws_config_cons = Dict[
    enabled => Bool,
    bucket => Str,
    prefix => Optional[Str]
  ];
  our $cloudwatch_cons = Dict[enabled => Bool];
  our $tags_cons = ArrayRef[Dict[key => Str, value => Str]];

  sub _body_params { [
    { name => 'name', required => 1, isa => Str },
    { name => 'authentication', required => 1, isa => $authentication_cons },
    { name => 'billing', isa => $billing_cons },
    { name => 'cloudtrail', isa => $cloudtrail_cons },
    { name => 'aws_config', isa => $aws_config_cons },
    { name => 'cloudwatch', isa => $cloudwatch_cons },
    { name => 'tags', isa => $tags_cons },
    { name => 'hide_public_fields', isa => Bool },
    { name => 'region', isa => Str },
  ] }
  sub _query_params { [ ] }
  sub _url_params { [ ] }
  sub _method { 'POST' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts' }

package CloudHealth::API::Call::AWSAccounts;
  use Types::Standard qw/Int/;

  sub _query_params { [
    { name => 'page', isa => Int },
    { name => 'per_page', isa => Int },
  ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts' }

package CloudHealth::API::Call::SingleAWSAccount;
  use Types::Standard qw/Int/;

  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'id', required => 1, isa => Int },
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts/:id' }

package CloudHealth::API::Call::UpdateExistingAWSAccount;
  use Types::Standard qw/Str Int Bool Dict Optional ArrayRef/;

  our $authentication_cons = Dict[
      protocol => Str,
      access_key => Optional[Str],
      secret_key => Optional[Str],
      assume_role_arn => Optional[Str],
      assume_role_external_id => Optional[Str],
    ];
  our $billing_cons = Dict[bucket => Str];
  our $cloudtrail_cons = Dict[
    enabled => Bool,
    bucket => Str,
    prefix => Optional[Str]
  ];
  our $aws_config_cons = Dict[
    enabled => Bool,
    bucket => Str,
    prefix => Optional[Str]
  ];
  our $cloudwatch_cons = Dict[enabled => Bool];
  our $tags_cons = ArrayRef[Dict[key => Str, value => Str]];

  sub _body_params { [
    { name => 'name', required => 1, isa => Str },
    { name => 'authentication', required => 1, isa => $authentication_cons },
    { name => 'billing', isa => $billing_cons },
    { name => 'cloudtrail', isa => $cloudtrail_cons },
    { name => 'aws_config', isa => $aws_config_cons },
    { name => 'cloudwatch', isa => $cloudwatch_cons },
    { name => 'tags', isa => $tags_cons },
    { name => 'hide_public_fields', isa => Bool },
    { name => 'region', isa => Str },
  ] }
  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'id', required => 1, isa => Str },
  ] }
  sub _method { 'PUT' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts/:id' }

package CloudHealth::API::Call::DeleteAWSAccount;
  use Types::Standard qw/Int/;

  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'id', required => 1, isa => Int },
  ] }
  sub _method { 'DELETE' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts/:id' }

package CloudHealth::API::Call::GetExternalID;
  use Types::Standard qw/Str Int Bool/;

  sub _query_params { [ ] }
  sub _url_params { [  
    { name => 'id', required => 1, isa => Str }
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_accounts/:id/generate_external_id' }

package CloudHealth::API::Call::RetrieveAllPerspectives;
  use Types::Standard qw/Bool/;

  sub _query_params { [ 
    { name => 'active_only', isa => Bool }
  ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/perspective_schemas' }

package CloudHealth::API::Call::RetrievePerspectiveSchema;
  use Types::Standard qw/Str Bool/;

  sub _query_params { [ 
    { name => 'include_version', isa => Bool },
  ] }
  sub _url_params { [ 
    { name => 'perspective_id', location => 'perspective-id', required => 1, isa => Str }
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/perspective_schemas/:perspective-id' }

package CloudHealth::API::Call::CreatePerspectiveSchema;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Bool HashRef/;

  has include_version => (is => 'ro', isa => Bool);
  has schema => (is => 'ro', isa => HashRef, required => 1);

  sub _body_params { [
    { name => 'schema' },
  ] }
  sub _query_params { [ 
    { name => 'include_version' },
  ] }
  sub _url_params { [ ] }
  sub _method { 'POST' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/perspective_schemas/' }

package CloudHealth::API::Call::UpdatePerspectiveSchema;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Bool HashRef Int/;

  has perspective_id => (is => 'ro', isa => Int, required => 1);
  has include_version => (is => 'ro', isa => Bool);
  has schema => (is => 'ro', isa => HashRef, required => 1);
  has allow_group_delete => (is => 'ro', isa => Bool);
  has check_version => (is => 'ro', isa => Int);

  sub _body_params { [
    { name => 'schema' },
  ] }
  sub _query_params { [ 
    { name => 'include_version' },
    { name => 'check_version' },
    { name => 'allow_group_delete' },
  ] }
  sub _url_params { [
    { name => 'perspective_id', location => 'perspective-id' }, 
  ] }
  sub _method { 'PUT' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/perspective_schemas/:perspective-id' }

package CloudHealth::API::Call::DeletePerspectiveSchema;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Bool HashRef Int/;

  has perspective_id => (is => 'ro', isa => Int, required => 1);
  has hard_delete => (is => 'ro', isa => Bool);
  has force => (is => 'ro', isa => Bool);

  sub _query_params { [
    { name => 'hard_delete' }, 
    { name => 'force' }, 
  ] }
  sub _url_params { [
    { name => 'perspective_id', location => 'perspective-id' }
  ] }
  sub _method { 'DELETE' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/perspective_schemas/:perspective-id' }

package CloudHealth::API::Call::ListQueryableReports;
  sub _query_params { [ ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/olap_reports' }

package CloudHealth::API::Call::ListReportsOfSpecificType;
  use Types::Standard qw/Str/;

  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'type', location => 'report-type', required => 1, isa => Str }    
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/olap_reports/:report-type' }

package CloudHealth::API::Call::ListOfQueryableAssets;
  sub _query_params { [ ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/api' }

package CloudHealth::API::Call::AttributesOfSingleAsset;
  use Types::Standard qw/Str/;

  sub _query_params { [ ] }
  sub _url_params { [ 
    { name => 'asset', required => 1, isa => Str }
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/api/:asset' }

package CloudHealth::API::Call::SearchForAssets;
  use Types::Standard qw/Str Int Bool/;

  sub _query_params { [
    { name => 'name', required => 1, isa => Str },
    { name => 'query', required => 1, isa => Str },
    { name => 'include', isa => Str },  
    { name => 'api_version', isa => Int, default => 2 },  
    { name => 'fields', isa => Str },  
    { name => 'page', isa => Int },
    { name => 'per_page', isa => Int },  
    { name => 'is_active', isa => Bool },
  ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/api/search' }

package CloudHealth::API::Call::MetricsForSingleAsset;
  use Types::Standard qw/Str Int/;

  sub _query_params { [
    { name => 'asset', required => 1, isa => Str },
    { name => 'granularity', isa => Str },
    { name => 'from', isa => Str },
    { name => 'to', isa => Str },
    { name => 'time_range', isa => Str },
    { name => 'page', isa => Int },
    { name => 'per_page', isa => Int },
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

package CloudHealth::API::Call::SpecificCustomerReport;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int Str/;

  has report_type => (is => 'ro', isa => Str, required => 1);
  has report_id => (is => 'ro', isa => Str, required => 1);
  has client_api_id => (is => 'ro', isa => Int, required => 1);

  sub _query_params { [
    { name => 'client_api_id' },  
  ] }
  sub _url_params { [
    { name => 'report_type', location => 'report-type' },
    { name => 'report_id', location => 'report-id' },
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/olap_reports/:report-type/:report-id' }

package CloudHealth::API::Call::AssetsForSpecificCustomer;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int Str/;

  has client_api_id => (is => 'ro', isa => Int, required => 1);
  has api_version => (is => 'ro', isa => Int, default => 2);
  has name => (is => 'ro', isa => Str, required => 1);

  sub _query_params { [
    { name => 'client_api_id' },  
    { name => 'api_version' },  
    { name => 'name' },  
  ] }
  sub _url_params { [ ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/api/search.json' }

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

package CloudHealth::API::Call::CreateAWSAccountAssignment;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int/;

  has owner_id => (is => 'ro', isa => Str, required => 1);
  has customer_id => (is => 'ro', isa => Int, required => 1);
  has payer_account_owner_id => (is => 'ro', isa => Str, required => 1);

  sub _body_params {
    [
      { name => 'owner_id' },
      { name => 'customer_id' },
      { name => 'payer_account_owner_id' },
    ]
  }
  sub _query_params { [ ] }
  sub _url_params { [ ] }
  sub _method { 'POST' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_account_assignments' }

package CloudHealth::API::Call::ReadAllAWSAccountAssignments;
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
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_account_assignments' }

package CloudHealth::API::Call::ReadSingleAWSAccountAssignment;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int/;
  
  has id => (is => 'ro', isa => Int, required => 1);

  sub _query_params { [ ] }
  sub _url_params { [
    { name => 'id' }  
  ] }
  sub _method { 'GET' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_account_assignments/:id' }

package CloudHealth::API::Call::UpdateAWSAccountAssignment;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Str Int/;

  has id => (is => 'ro', isa => Int, required => 1);
  has owner_id => (is => 'ro', isa => Str, required => 1);
  has customer_id => (is => 'ro', isa => Int, required => 1);
  has payer_account_owner_id => (is => 'ro', isa => Str, required => 1);

  sub _body_params { [
    { name => 'owner_id' },
    { name => 'customer_id' },
    { name => 'payer_account_owner_id' },
  ] }
  sub _query_params { [ ] }
  sub _url_params { [ 
    { name => 'id' },
  ] }
  sub _method { 'PUT' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_account_assignments/:id' }

package CloudHealth::API::Call::DeleteAWSAccountAssignment;
  use Moo;
  use MooX::StrictConstructor;
  use Types::Standard qw/Int/;

  has id => (is => 'ro', isa => Int, required => 1);

  sub _query_params { [ ] }
  sub _url_params { [ 
    { name => 'id' },
  ] }
  sub _method { 'DELETE' }
  sub _url { 'https://chapi.cloudhealthtech.com/v1/aws_account_assignments/:id' }

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
  sub CreatePerspectiveSchema {
    my $self = shift;
    $self->_invoke('CreatePerspectiveSchema', [ @_ ]);  
  }
  sub UpdatePerspectiveSchema {
    my $self = shift;
    $self->_invoke('UpdatePerspectiveSchema', [ @_ ]);   
  }
  sub DeletePerspectiveSchema {
    my $self = shift;
    $self->_invoke('DeletePerspectiveSchema', [ @_ ]);    
  }

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

  sub UpdateTagsForSingleAsset { die "TODO" }

  sub SpecificCustomerReport {
    my $self = shift;
    $self->_invoke('SpecificCustomerReport', [ @_ ]); 
  }
  sub AssetsForSpecificCustomer {
    my $self = shift;
    $self->_invoke('AssetsForSpecificCustomer', [ @_ ]);
  }
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
  
  sub CreateAWSAccountAssignment {
    my $self = shift;
    $self->_invoke('CreateAWSAccountAssignment', [ @_ ]);
  }
  sub ReadAllAWSAccountAssignments {
    my $self = shift;
    $self->_invoke('ReadAllAWSAccountAssignments', [ @_ ]);
  }
  sub ReadSingleAWSAccountAssignment {
    my $self = shift;
    $self->_invoke('ReadSingleAWSAccountAssignment', [ @_ ]); 
  }
  sub UpdateAWSAccountAssignment {
    my $self = shift;
    $self->_invoke('UpdateAWSAccountAssignment', [ @_ ]); 
  }
  sub DeleteAWSAccountAssignment { 
    my $self = shift;
    $self->_invoke('DeleteAWSAccountAssignment', [ @_ ]);  
  }

1;
