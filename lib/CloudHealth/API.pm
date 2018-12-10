package CloudHealth::Net::HTTPRequest;
  use Moo;
  use Types::Standard qw/Str HashRef/;

  has method => (is => 'rw', isa => Str);
  has url => (is => 'rw', isa => Str);
  has headers => (is => 'rw', isa => HashRef);
  has parameters => (is => 'rw', isa => HashRef);
  has content => (is => 'rw', isa => Str);

package CloudHealth::Net::HTTPResponse;
  use Moo;
  use Types::Standard qw/Str Int/;

  has content => (is => 'ro', isa => Str);
  has status => (is => 'ro', isa => Int);

package CloudHealth::API;
  use Moo;
  use Types::Standard qw/HasMethods/;

  our $VERSION = '0.01';

  has call_former => (is => 'ro', isa => HasMethods['params2request'], default => sub {
    require CloudHealth::API::CallObjectFormer;
    CloudHealth::API::CallObjectFormer->new;  
  });
  has credentials => (is => 'ro', isa => HasMethods['api_key'], default => sub {
    require CloudHealth::API::Credentials;
    CloudHealth::API::Credentials->new;
  });
  has io => (is => 'ro', isa => HasMethods['call'], default => sub {
    require CloudHealth::API::Caller;
    CloudHealth::API::Caller->new;
  });
  has result_parser => (is => 'ro', isa => HasMethods['result2return'], default => sub {
    require CloudHealth::API::ResultParser;
    CloudHealth::API::ResultParser->new
  });

  sub _invoke {
    my ($self, $method, $params) = @_;
    my $req = $self->call_former->params2request($method, $self->credentials, $params);
    my $result = $self->io->call($req);
    return $self->result_parser->result2return($result);
  }

  sub method_classification {
    {
      aws_accounts => [ qw/EnableAWSAccount AWSAccounts SingleAWSAccount 
                           UpdateExistingAWSAccount DeleteAWSAccount GetExternalID/ ],
      perspectives => [ qw/RetrieveAllPerspectives RetrievePerspectiveSchema CreatePerspectiveSchema
                           UpdatePerspectiveSchema DeletePerspectiveSchema/ ],
      reports      => [ qw/ListQueryableReports ListReportsOfSpecificType DataForStandardReport 
                           DataForCustomReport ReportDimensionsAndMeasures/ ],
      assets       => [ qw/ListOfQueryableAssets AttributesOfSingleAsset SearchForAssets/ ],
      metrics      => [ qw/MetricsForSingleAsset UploadMetricsForSingleAsset/ ],
      tags         => [ qw/UpdateTagsForSingleAsset/ ],
      partner      => [ qw/SpecificCustomerReport AssetsForSpecificCustomer CreatePartnerCustomer 
                           ModifyExistingCustomer DeleteExistingCustomer GetSingleCustomer GetAllCustomers
                           StatementForSingleCustomer StatementsForAllCustomers
                           CreateAWSAccountAssignment ReadAllAWSAccountAssignments 
                           ReadSingleAWSAccountAssignment UpdateAWSAccountAssignment 
                           DeleteAWSAccountAssignment/ ],
      gov_cloud    => [ qw/ConnectGovCloudCommercialAccountToGovCloudAssetAccount
                           ListAllGovCloudLinkagesOwnedByCurrentCustomer
                           DetailsOfSingleGovCloudLinkage UpdateSingleGovCloudLinkage
                           UnderstandFormatOfGovCloudLinkagePayload/ ],
    }
  }

  sub EnableAWSAccount {
    my $self = shift;
    $self->_invoke('EnableAWSAccount', [ @_ ]);
  }
  sub AWSAccounts {
    my $self = shift;
    $self->_invoke('AWSAccounts', [ @_ ]);
  }
  sub SingleAWSAccount {
    my $self = shift;
    $self->_invoke('SingleAWSAccount', [ @_ ]);
  }
  sub UpdateExistingAWSAccount {
    my $self = shift;
    $self->_invoke('UpdateExistingAWSAccount', [ @_ ]);
  }
  sub DeleteAWSAccount {
    my $self = shift;
    $self->_invoke('DeleteAWSAccount', [ @_ ]);
  }
  sub GetExternalID {
    my $self = shift;
    $self->_invoke('GetExternalID', [ @_ ]); 
  }

  sub RetrieveAllPerspectives {
    my $self = shift;
    $self->_invoke('RetrieveAllPerspectives', [ @_ ]);
  }

  sub RetrievePerspectiveSchema {
    my $self = shift;
    $self->_invoke('RetrievePerspectiveSchema', [ @_ ]);
  }
  sub CreatePerspectiveSchema {
    my $self = shift;
    $self->_invoke('CreatePerspectiveSchema', [ @_ ]);  
  }
  sub UpdatePerspectiveSchema {
    my $self = shift;
    $self->_invoke('UpdatePerspectiveSchema', [ @_ ]);   
  }
  sub DeletePerspectiveSchema {
    my $self = shift;
    $self->_invoke('DeletePerspectiveSchema', [ @_ ]);    
  }

  sub ListQueryableReports {
    my $self = shift;
    $self->_invoke('ListQueryableReports', [ @_ ]);
  }

  sub ListReportsOfSpecificType {
    my $self = shift;
    $self->_invoke('ListReportsOfSpecificType', [ @_ ]);
  }

  sub DataForStandardReport { die "TODO" }
  sub DataForCustomReport { die "TODO" }
  sub ReportDimensionsAndMeasures { die "TODO" }

  sub ListOfQueryableAssets {
    my $self = shift;
    $self->_invoke('ListOfQueryableAssets', [ @_ ]);
  }

  sub AttributesOfSingleAsset {
    my $self = shift;
    $self->_invoke('AttributesOfSingleAsset', [ @_ ]);
  }

  sub SearchForAssets {
    my $self = shift;
    $self->_invoke('SearchForAssets', [ @_ ]);
  }

  sub MetricsForSingleAsset {
    my $self = shift;
    $self->_invoke('MetricsForSingleAsset', [ @_ ]);
  }

  sub UploadMetricsForSingleAsset { die "TODO" }

  sub UpdateTagsForSingleAsset {
    my $self = shift;
    $self->_invoke('UpdateTagsForSingleAsset', [ @_ ]);
  }

  sub SpecificCustomerReport {
    my $self = shift;
    $self->_invoke('SpecificCustomerReport', [ @_ ]); 
  }
  sub AssetsForSpecificCustomer {
    my $self = shift;
    $self->_invoke('AssetsForSpecificCustomer', [ @_ ]);
  }
  sub CreatePartnerCustomer {
    my $self = shift;
    $self->_invoke('CreatePartnerCustomer', [ @_ ]);  
  }
  sub ModifyExistingCustomer {
    my $self = shift;
    $self->_invoke('ModifyExistingCustomer', [ @_ ]);  
  }
  sub DeleteExistingCustomer {
    my $self = shift;
    $self->_invoke('DeleteExistingCustomer', [ @_ ]);  
  }
  sub GetSingleCustomer {
    my $self = shift;
    $self->_invoke('GetSingleCustomer', [ @_ ]);
  }
  sub GetAllCustomers {
    my $self = shift;
    $self->_invoke('GetAllCustomers', [ @_ ]); 
  }
  sub StatementForSingleCustomer {
    my $self = shift;
    $self->_invoke('StatementForSingleCustomer', [ @_ ]);
  }
  sub StatementsForAllCustomers {
    my $self = shift;
    $self->_invoke('StatementsForAllCustomers', [ @_ ]);
  }

  sub ConnectGovCloudCommercialAccountToGovCloudAssetAccount { die "TODO" }
  sub ListAllGovCloudLinkagesOwnedByCurrentCustomer { die "TODO" }
  sub DetailsOfSingleGovCloudLinkage { die "TODO" }
  sub UpdateSingleGovCloudLinkage { die "TODO" }
  sub UnderstandFormatOfGovCloudLinkagePayload { die "TODO" }
  
  sub CreateAWSAccountAssignment {
    my $self = shift;
    $self->_invoke('CreateAWSAccountAssignment', [ @_ ]);
  }
  sub ReadAllAWSAccountAssignments {
    my $self = shift;
    $self->_invoke('ReadAllAWSAccountAssignments', [ @_ ]);
  }
  sub ReadSingleAWSAccountAssignment {
    my $self = shift;
    $self->_invoke('ReadSingleAWSAccountAssignment', [ @_ ]); 
  }
  sub UpdateAWSAccountAssignment {
    my $self = shift;
    $self->_invoke('UpdateAWSAccountAssignment', [ @_ ]); 
  }
  sub DeleteAWSAccountAssignment { 
    my $self = shift;
    $self->_invoke('DeleteAWSAccountAssignment', [ @_ ]);  
  }

1;
