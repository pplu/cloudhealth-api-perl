requires 'Moose';
requires 'MooseX::StrictConstructor';
requires 'Throwable::Error';
requires 'HTTP::Tiny';
requires 'JSON::MaybeXS';

on test => sub {
  requires 'Test::More';
  requires 'Test::Exception';
};
