#!/usr/bin/env perl

use warnings;
use strict;
use utf8;

my %groups;
my @order;

my $doc_id = shift @ARGV;

my %category_map = (
  a => 'anonymous',
  ap => 'anonymous-partial',
  u => 'unofficial',
  onp => 'official-non-political',
  op => 'official-political',
);

while (<>) {
  chomp;
  my ($sd, $tei) = ("", "");

  my @fields = split /\t/;
	my $misc = $fields[9];
  next unless $misc;
  my @miscs = split /\|/, $misc;

  # Extract SD and TeiID
  for my $f (@miscs) {
    $sd  = substr($f, 3) if $f =~ /^SD=/;
    $tei = substr($f, 6) if $f =~ /^TeiID=/;
  }

  if ($sd ne "" && $tei ne "") {
    my ($sd_type, $sd_num, $sd_cat) = split /_/, $sd;
    unless(exists $groups{$sd_num}) {
			push @order, $sd_num;
			$groups{$sd_num} = {};
		}
		$groups{$sd_num}->{$sd_type} //= {tokens => []};
    push @{$groups{$sd_num}->{$sd_type}->{tokens}}, $tei;
    if($sd_cat) {
		  $groups{$sd_num}->{$sd_type}->{category} = $category_map{$sd_cat}//$sd_cat;
      print STDERR "ERROR: unknown category $sd_cat in $tei\n" unless exists $category_map{$sd_cat};
    }
  }
}



print '<?xml version="1.0" encoding="UTF-8"?>'."\n";
print '<TEI xmlns="http://www.tei-c.org/ns/1.0">'."\n";
print '  <spanGrp type="ATTRIBUTION">'."\n";

# print MWEs
for my $sd_num (@order) {
  for my $sd_type (keys %{$groups{$sd_num}}) {
    my $sd_id = "$doc_id.sd$sd_type$sd_num";
    printf qq{    <span xml:id="%s" ana="attrib:%s" target="%s"/>\n},
             $sd_id,
             ($sd_type eq 'P' ? 'phrase' : $groups{$sd_num}->{$sd_type}->{category}),
             join(" ", map { "#$_" } @{ $groups{$sd_num}->{$sd_type}->{tokens} });
    $groups{$sd_num}->{($sd_type eq 'P' ? 'signal' : 'source')} = $sd_id;
  }
}

print "  </spanGrp>
  <linkGrp targFunc=\"signal source\" type=\"ATTRIBUTION\">
";
# print Links
for my $sd_num (@order) {
  if (exists $groups{$sd_num}->{signal}
      && exists $groups{$sd_num}->{source} ) {
    printf qq{    <link target="#%s #%s"/>\n},
             $groups{$sd_num}->{signal},
             $groups{$sd_num}->{source};
  }
}
print "  </linkGrp>
</TEI>";
