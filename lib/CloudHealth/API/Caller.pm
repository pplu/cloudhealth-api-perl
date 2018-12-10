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
1;
