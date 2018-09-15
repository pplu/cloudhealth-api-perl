#!/usr/bin/env perl

use strict;
use warnings;


use CloudHealth::API;
use Data::Dumper;

my $key = $ARGV[0] or die "Usage: $0 api_key asset_id";
my $asset = $ARGV[0] or die "Usage: $0 api_key asset_id";

my $ch = CloudHealth::API->new(
  credentials => CloudHealth::API::Credentials->new(
    api_key => $key,
  ),
);

{
  my $res = $ch->MetricsForSingleAsset(
    asset => $asset,
  );
  print Dumper($res);
}

