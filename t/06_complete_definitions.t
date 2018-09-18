#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use CloudHealth::API;
use Ref::Util qw/is_plain_arrayref/;

my $ch = CloudHealth::API->new(
  credentials => CloudHealth::API::Credentials->new(api_key => 'stub')
);

my $classified_methods = {};
# See that all the methods in method_classification are effectively declared
# fill in classified_methods so we can later detect if there are methods in 
# the API that have not been classified
foreach my $kind (keys %{ $ch->method_classification }) {
  foreach my $method (@{ $ch->method_classification->{ $kind } }) {
    my $metadata = eval { $ch->call_former->call_metadata($method) };
    if ($@) {
      fail("Can't load metadata for $method");
      next;
    }
    ok(is_plain_arrayref($metadata->{ query_params }), "query_params is an array for $method");
    foreach (@{ $metadata->{ query_params } }) {
      ok(defined $_->{ name }); 
      ok(defined $_->{ isa }); 
    }
    ok(is_plain_arrayref($metadata->{ url_params }), "url_params is an array for $method");
    foreach (@{ $metadata->{ url_params } }) {
      ok(defined $_->{ name });
      ok(defined $_->{ isa });
    }

    if (defined $metadata->{ body_params }) {
      ok(is_plain_arrayref($metadata->{ body_params }), "body_params is an array for $method");
      foreach (@{ $metadata->{ body_params } }) {
        ok(defined $_->{ name });
        ok(defined $_->{ isa });
      }
    }

    ok(defined $metadata->{ url }, "URL is set for $method");
    ok(defined $metadata->{ method }, "method is set for $method");
  }
}

done_testing;
