#!/usr/bin/env perl

use Test::More;
use Test::Exception;
use CloudHealth::API;

my $creds = CloudHealth::API::Credentials->new(api_key => 'stub');
my $former = CloudHealth::API::CallObjectFormer->new;

{
  my $req = $former->params2request('RetrieveAllPerspectives', $creds);
  like($req->url, qr|^https://chapi.cloudhealthtech.com/v1/perspective_schemas|, 'found correct url');
  like($req->url, qr/api_key=stub/, 'found api_key in the params of the url');
}

{
  throws_ok(sub {
    $former->params2request('RetrievePerspectiveSchema', $creds);
  }, 'Moose::Exception::AttributeIsRequired', 'RetrievePerspectiveSchema call perspective_id parameter is required');
}

{
  my $req = $former->params2request('RetrievePerspectiveSchema', $creds, perspective_id => 'pid');
  like($req->url, qr|/perspective_schemas/pid|, 'found the perspective_id in the url');
  unlike($req->url, qr|include_version=|, 'Didn\'t find optional unspecified include_version');
}

{
  my $req = $former->params2request('RetrieveAllPerspectives', $creds, active_only => 1);
  like($req->url, qr/active_only=1/, 'found active_only as a parameter in the params of the url');
}

{
  throws_ok(sub {
    $former->params2request('RetrievePerspectiveSchema', $creds, perspective_id => 'x', unexistant => 'value');
  }, qr/Found unknown attribute/, 'RetrievePerspectiveSchema doesn\'t have that parameter');
}

done_testing;
