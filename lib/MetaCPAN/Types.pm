package MetaCPAN::Types;

use strict;
use warnings;

use parent 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(
    qw(
        MooseX::Types::Common::Numeric
        MooseX::Types::Common::String
        MooseX::Types::Moose
        MooseX::Types::Path::Class
        MooseX::Types::Structured
        MooseX::Types::URI
        MetaCPAN::Types::Internal
        )
);

1;
