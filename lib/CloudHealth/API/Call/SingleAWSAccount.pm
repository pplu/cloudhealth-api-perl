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

1;
