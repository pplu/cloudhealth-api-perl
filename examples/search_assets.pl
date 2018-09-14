#!/usr/bin/env perl

use CloudHealth::API;
use Data::Dumper;

my $key = $ARGV[0] or die "Usage: $0 api_key";

my $ch = CloudHealth::API->new(
  credentials => CloudHealth::API::Credentials->new(
    api_key => $key,
  ),
);

{
  my $res = $ch->SearchForAssets(
    name => 'AwsInstance',
    query => 'is_active=1',
  );
  print Dumper($res);
}

