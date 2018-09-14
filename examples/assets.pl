#!/usr/bin/env perl

use CloudHealth::API;
use Data::Dumper;

my $key = $ARGV[0] or die "Usage: $0 api_key";

my $ch = CloudHealth::API->new(
  credentials => CloudHealth::API::Credentials->new(
    api_key => $key,
  ),
);

my $random_asset;
{
  my $res = $ch->ListOfQueryableAssets;
  print Dumper($res);
  $random_asset = $res->[0];
}

{
  my $res = $ch->AttributesOfSingleAsset(asset => $random_asset);
  print Dumper($res);
}
