package CloudHealth::API::Error;
  use Moose;
  extends 'Throwable::Error';

  has status => (is => 'ro', isa => 'Int', required => 1);
  has detail => (is => 'ro', isa => 'Str');

  sub as_string {
    my $self = shift;
    if (defined $self->detail) {
      return sprintf "Exception: %s on HTTP response %d.\nDetail: %s", $self->message, $self->status, $self->detail;
    } else {
      return sprintf "Exception: %s on HTTP response %d", $self->message, $self->status;
    }
  }

package CloudHealth::API::Credentials;
  use Moose;

  has api_key => (is => 'ro', isa => 'Str', required => 1);

package CloudHealth::Net::HTTPRequest;
  use Moose;

  has method => (is => 'rw', isa => 'Str');
  has url => (is => 'rw', isa => 'Str');
  has headers => (is => 'rw', isa => 'HashRef');
  has parameters => (is => 'rw', isa => 'HashRef');

package CloudHealth::Net::HTTPResponse;
  use Moose;

  has content => (is => 'ro', isa => 'Str');
  has status => (is => 'ro', isa => 'Int');

package CloudHealth::API::CallObjectFormer;
  use Moose;
  use HTTP::Tiny;

  sub params2request {
    my ($self, $call, $creds, @params) = @_;

    my $call_object = "CloudHealth::API::Call::$call"->new(@params);

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
  use Moose;
  use MooseX::StrictConstructor;

  has active_only => (is => 'ro', isa => 'Bool');

  has _parameters => (is => 'ro', default => sub { [ 
    { name => 'active_only' }
  ] });
  has _url_params => (is => 'ro', default => sub { [ ] });

  has _method => (is => 'ro', isa => 'Str', default => 'GET');
  has _url => (is => 'ro', isa => 'Str', default => 'https://chapi.cloudhealthtech.com/v1/perspective_schemas');

package CloudHealth::API::Call::RetrievePerspectiveSchema;
  use Moose;
  use MooseX::StrictConstructor;

  has include_version => (is => 'ro', isa => 'Bool');
  has perspective_id => (is => 'ro', isa => 'Str', required => 1);

  has _parameters => (is => 'ro', default => sub { [ 
    { name => 'include_version' },
  ] });
  has _url_params => (is => 'ro', default => sub { [ 
    { name => 'perspective_id', location => 'perspective-id' }
  ] });

  has _method => (is => 'ro', isa => 'Str', default => 'GET');
  has _url => (is => 'ro', isa => 'Str', default => 'https://chapi.cloudhealthtech.com/v1/perspective_schemas/:perspective-id');

package CloudHealth::API::Call::ListQueryableReports;
  use Moose;
  use MooseX::StrictConstructor;

  has _parameters => (is => 'ro', default => sub { [ ] });
  has _url_params => (is => 'ro', default => sub { [ ] });

  has _method => (is => 'ro', isa => 'Str', default => 'GET');
  has _url => (is => 'ro', isa => 'Str', default => 'https://chapi.cloudhealthtech.com/olap_reports');

package CloudHealth::API::Call::ListReportsOfSpecificType;
  use Moose;
  use MooseX::StrictConstructor;

  has type => (is => 'ro', isa => 'Str', required => 1);

  has _parameters => (is => 'ro', default => sub { [ ] });
  has _url_params => (is => 'ro', default => sub { [
    { name => 'type', location => 'report-type' }    
  ] });

  has _method => (is => 'ro', isa => 'Str', default => 'GET');
  has _url => (is => 'ro', isa => 'Str', default => 'https://chapi.cloudhealthtech.com/olap_reports/:report-type');

package CloudHealth::API::Caller;
  use Moose;
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
  use Moose;
  use JSON::MaybeXS;

  has parser => (is => 'ro', default => sub { JSON::MaybeXS->new });

  sub result2return {
    my ($self, $response) = @_;

    if ($response->status == 200) {
      return $self->process_response($response);
    } elsif ($response->status == 401) {
      # We don't let process_error process a 401 because it returns this content:
      # {"error":""}
      # which is not consistent with http://apidocs.cloudhealthtech.com/#documentation_error-codes
      # so process_error will not return adequately
      return CloudHealth::API::Error->throw(
        status => $response->status,
        message => 'Unauthorized',
      );
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
      status => $response->status,
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
      status => $response->status,
      message => 'Can\'t parse JSON content',
      detail => $response->content,
    ) if ($@);

    CloudHealth::API::Error->throw(
      status => $response->status,
      message => 'Error from API doesn\'t meet docu requirements',
      detail => $response->content,
    ) if (
         not defined $struct->{ error } 
      or not defined $struct->{ message }
      or $struct->{ error } != 1
    );

    CloudHealth::API::Error->throw(
      status => $response->status,
      message => $struct->{ message },
    )
  }
package CloudHealth::API;
  use Moose;

  has call_former => (is => 'ro', isa => 'CloudHealth::API::CallObjectFormer', default => sub {
    CloudHealth::API::CallObjectFormer->new;  
  });
  has credentials => (is => 'ro', isa => 'CloudHealth::API::Credentials', required => 1);
  has io => (is => 'ro', isa => 'CloudHealth::API::Caller', default => sub {
    CloudHealth::API::Caller->new;  
  });
  has result_parser => (is => 'ro', isa => 'CloudHealth::API::ResultParser', default => sub {
    CloudHealth::API::ResultParser->new
  });

  sub RetrieveAllPerspectives {
    my ($self, @params) = @_;
    my $req = $self->call_former->params2request('RetrieveAllPerspectives', $self->credentials, @params);
    my $result = $self->io->call($req);
    return $self->result_parser->result2return($result);
  }

  sub RetrievePerspectiveSchema {
    my ($self, @params) = @_;
    my $req = $self->call_former->params2request('RetrievePerspectiveSchema', $self->credentials, @params);
    my $result = $self->io->call($req);
    return $self->result_parser->result2return($result);
  }

  sub ListQueryableReports {
    my ($self, @params) = @_;
    my $req = $self->call_former->params2request('ListQueryableReports', $self->credentials, @params);
    my $result = $self->io->call($req);
    return $self->result_parser->result2return($result);
  }

  sub ListReportsOfSpecificType {
    my ($self, @params) = @_;
    my $req = $self->call_former->params2request('ListReportsOfSpecificType', $self->credentials, @params);
    my $result = $self->io->call($req);
    return $self->result_parser->result2return($result);
  }

1;
