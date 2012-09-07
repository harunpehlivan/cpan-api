#!/usr/bin/env perl
# PODNAME: check_prereqs.pl

# TODO: this stuff should be in other modules somewhere

use strict;
use warnings;
use Perl::PrereqScanner 1.014;
use CPAN::Meta::Requirements;
use File::Find qw( find );
use version 0.77;

my $dir = '.';

# CPAN::Meta::Prereqs
# File::Find::Rule->not( File::Find::Rule->name('var')->prune->discard )->perl_file->in('.')
my $local = {};
my $files = {};
{
  my $phase = 'runtime';
  find(
    {
      # FIXME: unix slashes
      wanted => sub {
        my $phase =
          # beneath t/ or xt/
          m{^(\./)?x?t/} ? 'build' :
          'runtime';

        push @{ $files->{ $phase } }, $_
          if /\.(pm|pl|t)$/i;

        if( m{^(?:\./)?(?:t/)?lib/(.+?)\.pm$} ){
          (my $pm = $1) =~ s!/!::!g;
          $local->{ $pm } = $_;
        }
      },
      no_chdir => 1,
    },
    # TODO: ignore qw( .git var )
    $dir,
  );
}

my $scanner = Perl::PrereqScanner->new(
  # TODO: extra_scanners => [qw( PlackMiddleware Catalyst )],
);

my $reqs = {};

foreach my $phase ( keys %$files ){
  my $pr = CPAN::Meta::Requirements->new;
  foreach my $file ( @{ $files->{ $phase } } ){
    $pr->add_requirements( $scanner->scan_file( $file ) );
  }
  $reqs->{ $phase } = $pr->as_string_hash;
}

# don't duplicate runtime deps into build deps
foreach my $dep ( keys %{ $reqs->{runtime} } ){
  # TODO: check version
  delete $reqs->{build}{ $dep };
}

# ignore packages we provide locally
foreach my $phase ( keys %$files ){
  #$reqs->clear_requirements($_) for grep { exists $local->{$_} } $reqs->required_modules;
  foreach my $dep ( keys %{ $reqs->{ $phase } } ){
    delete $reqs->{ $phase }{ $dep }
      if $local->{ $dep };
  }
}

sub check_prereqs {
  my ($scanned, $mm) = @_;
  foreach my $dep ( keys %$scanned ){
    if( exists($mm->{ $dep }) ){
      delete $scanned->{ $dep }
        if version->parse($scanned->{ $dep }) <= version->parse($mm->{ $dep });
    }
  }
}

my ($PREREQ_PM, $BUILD_REQUIRES, $MIN_PERL_VERSION);

my $mm_prereqs = qx{$^X Makefile.PL PREREQ_PRINT=1};
eval $mm_prereqs;

check_prereqs($reqs->{runtime}, $PREREQ_PM);
check_prereqs($reqs->{build}, $BUILD_REQUIRES);
delete $reqs->{runtime}{perl}
  if version->parse($reqs->{runtime}{perl}) <= version->parse($MIN_PERL_VERSION);

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
#print Dumper({ local => $local, files => $files, });
#print Dumper({ PPM => $PREREQ_PM, BR => $BUILD_REQUIRES });
print Dumper($reqs);
