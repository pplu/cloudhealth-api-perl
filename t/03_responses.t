#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use CloudHealth::API;

my $res_processor = CloudHealth::API::ResultParser->new;

{
  my $res = $res_processor->result2return(
    CloudHealth::Net::HTTPResponse->new(
      status => 200,
      content => '{}'
    )
  );

  ok(ref($res) eq 'HASH');
}

{
  throws_ok(sub{
    $res_processor->result2return(
      CloudHealth::Net::HTTPResponse->new(
        status => 200,
        content => '{"malformed_json":}'
      )
    );
  }, 'CloudHealth::API::Error');
  cmp_ok($@->type, 'eq', 'UnparseableResponse');
  like($@->message, qr|Can't parse response|);
  like($@->message, qr|malformed JSON string|);
}

{
  throws_ok(sub{
    $res_processor->result2return(
      CloudHealth::Net::HTTPResponse->new(
        status => 401,
        content => '{"error":"You need to sign in or sign up before continuing"}'
      )
    );
  }, 'CloudHealth::API::RemoteError');
  cmp_ok($@->type, 'eq', 'Remote');
  cmp_ok($@->message, 'eq', 'You need to sign in or sign up before continuing');
}

{
  throws_ok(sub{
    $res_processor->result2return(
      CloudHealth::Net::HTTPResponse->new(
        status => 401,
        content => '{"error":"You need to sign in or sign up before continuing"}'
      )
    );
  }, 'CloudHealth::API::RemoteError');
  cmp_ok($@->type, 'eq', 'Remote');
  cmp_ok($@->message, 'eq', 'You need to sign in or sign up before continuing');
}


{
  throws_ok(sub{
    $res_processor->result2return(
      CloudHealth::Net::HTTPResponse->new(
        status => 403,
        content => '{}'
      )
    );
  }, 'CloudHealth::API::RemoteError');
  cmp_ok($@->type, 'eq', 'Remote');
  cmp_ok($@->message, 'eq', 'No message');
}



done_testing;