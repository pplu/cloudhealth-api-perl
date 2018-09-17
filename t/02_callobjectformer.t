#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use CloudHealth::API;

my $creds = CloudHealth::API::Credentials->new(api_key => 'stub');
my $former = CloudHealth::API::CallObjectFormer->new;

{
  my $req = $former->params2request('RetrieveAllPerspectives', $creds, []);
  like($req->url, qr|^https://chapi.cloudhealthtech.com/v1/perspective_schemas|, 'found correct url');
  like($req->url, qr/api_key=stub/, 'found api_key in the params of the url');
}

{
  throws_ok(sub {
    $former->params2request('RetrievePerspectiveSchema', $creds, []);
  }, 'CloudHealth::API::Error', 'RetrievePerspectiveSchema call perspective_id parameter is required');
  cmp_ok($@->message, 'eq', 'Error in parameters to method RetrievePerspectiveSchema');
  like($@->detail, qr/Missing required arguments/);
}

{
  my $req = $former->params2request('RetrievePerspectiveSchema', $creds, [ perspective_id => 'pid' ]);
  like($req->url, qr|/perspective_schemas/pid|, 'found the perspective_id in the url');
  unlike($req->url, qr|include_version=|, 'Didn\'t find optional unspecified include_version');
}

{
  my $req = $former->params2request('RetrieveAllPerspectives', $creds, [ active_only => 1 ]);
  like($req->url, qr/active_only=1/, 'found active_only as a parameter in the params of the url');
}

{
  throws_ok(sub {
    $former->params2request('RetrievePerspectiveSchema', $creds, [ perspective_id => 'x', unexistant => 'value' ]);
  }, 'CloudHealth::API::Error', 'RetrievePerspectiveSchema doesn\'t have that parameter');
  cmp_ok($@->message, 'eq', 'Error in parameters to method RetrievePerspectiveSchema');
  like($@->detail, qr/Found unknown attribute/);
}

{
  my $req = $former->params2request('SearchForAssets', $creds, [ name => 'fake', query => 'fake' ]);
  like($req->url, qr/api_version=2/, 'found default api_version in the params');
}

{
  my $req = $former->params2request('SearchForAssets', $creds, [ api_version => 1, name => 'fake', query => 'fake' ]);
  like($req->url, qr/api_version=1/, 'found overwritten api_version in the params');
}

{
  throws_ok(sub {
    $former->params2request('EnableAWSAccount', $creds, [ name => 'test' ]);
  }, 'CloudHealth::API::Error');
  like($@->detail, qr/Missing required arguments: authentication/);
}

{
  my $req = $former->params2request('EnableAWSAccount', $creds, [
    name => 'test',
    authentication => { protocol => 'assume_role' },
    billing => { bucket => 'billing_bucket' },
    tags => [ { key => 'tag1name', value => 'tag1value' } ]
  ]);
  cmp_ok($req->method, 'eq', 'POST');
  like($req->content, qr|"name":"test"|);
}

done_testing;
