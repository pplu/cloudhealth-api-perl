requires 'Moo';
requires 'MooX::StrictConstructor';
requires 'Type::Tiny';
requires 'Throwable::Error';
requires 'HTTP::Tiny';
requires 'JSON::MaybeXS';
requires 'IO::Socket::SSL';
requires 'Module::Runtime';

on test => sub {
  requires 'Test::More';
  requires 'Test::Exception';
};
