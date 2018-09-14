#!/usr/bin/env perl

use CloudHealth::API;
use Data::Dumper;

my $key = $ARGV[0] or die "Usage: $0 api_key";

my $ch = CloudHealth::API->new(
  credentials => CloudHealth::API::Credentials->new(
    api_key => $key,
  ),
);

my $random_id;
{
  my $res = $ch->RetrieveAllPerspectives(active_only => 1);
  print Dumper($res);
  $random_id = [ keys %$res ]->[0];
}
{
  my $res = $ch->RetrievePerspectiveSchema(perspective_id => $random_id);
  print Dumper($res);
}
