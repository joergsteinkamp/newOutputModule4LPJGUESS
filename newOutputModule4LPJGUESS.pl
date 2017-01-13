#!/usr/bin/env perl

use warnings;
use strict;
#use Getopt::Long qw(:config no_ignore_case);
#use File::Basename;
#use Time::gmtime;
use XML::LibXML;

my $fname = shift;

#################################
### Define the output culumns ###
#################################
sub column_definition($$$) {
    my $name        = shift;
    my $columns_ref = shift;
    my $use_tables  = shift;

    my $column_def = "";
    if ($use_tables) {
        print("Not yet ready!");
    } else {
        my $cnames = join ' ', map {
            $_->{name};
        } @$columns_ref;
        $column_def = "        fprintf(out_${name}, 'Lon Lat Year ".$cnames."');\n";
    }
    return($column_def);
}

###########################################################
### function returning the beginning of the h/cpp files ###
###########################################################
sub header($$$$) {
    my $name      = shift;
    my $long_name = shift;
    my $author    = shift;
    my $suffix    = shift;

    my $curr_time = localtime();
    my $uc_name   = uc($name);
    my $ucf_name  = ucfirst($name);
    my $header    = qq{//////////////////////////////////////////////////////////////////////////////////////
/// \\file ${name}output.${suffix}
/// \\brief Output module for $long_name
///
/// \\author $author
/// \$Date: $curr_time \$
///
///////////////////////////////////////////////////////////////////////////////////////
};
    if ($suffix eq "cpp") {
        $header .= qq{#include "config.h"
#include "${name}output.h"
#include "parameters.h"
#include "guess.h"
namespace GuessOutput \{
  REGISTER_OUTPUT_MODULE("${name}", ${ucf_name}Output)
};  
    } elsif ($suffix eq "h") {
        $header .= qq{#ifndef LPJ_GUESS_${uc_name}_OUTPUT_H
#define LPJ_GUESS_${uc_name}_OUTPUT_H
#include "outputmodule.h"
#include "outputchannel.h"
#include "gutil.h"
namespace GuessOutput \{
  class ${ucf_name}Output : public OutputModule \{
  public:
    ${ucf_name}Output();
    ~${ucf_name}Output();
    void init();
    void outannual(Gridcell& gridcell);
    void outdaily(Gridcell& gridcell);
  private:
};
    } else {
        return(0);
    }
    return($header);
}
#####################################################
### function returning the tail of the h/cpp file ###
#####################################################
sub tail($$) {
    my $name = shift;
    my $suffix = shift;
    my $ucf_name = ucfirst($name);
    my $tail;
    if ($suffix eq "cpp") {
        $tail = qq{///* DEFINE DAILY OUTOUT HERE *///
  void ${ucf_name}Output::outdaily(Gridcell& gridcell) \{
    return;
  \}
///* DEFINE ANNUAL AND MONTHLY OUTPUT HERE *///
  void ${ucf_name}Output::outannual(Gridcell& gridcell) \{
    return;
  \}
\}
};
    } elsif ($suffix eq "h") {
        $tail = qq{  \};
\}
#endif
};
    } else {
        return(0);
    }
    return($tail);     
}
#############################################################
### function to declare the output variable in the header ###
#############################################################
sub declare($$) {
    my $ref_files = shift;
    my $use_tables = shift;
    my @files = @$ref_files;
    my $dec = "";
    while (@files) {
        my $v = shift(@files);
        $dec .= "    xtring file_$v;\n";
        if ($use_tables) {
            $dec .= "    Table *out_$v;\n";
        } else {
            $dec .= "    FILE *out_$v;\n";
        }
    }
    return($dec);
}
###############################################
### function to declare ins-file parameters ###
###############################################
sub declare_ins($$$) {
    my $name                  = shift;
    my $ref_files             = shift;
    my $ref_files_description = shift;
    my $ucf_name = ucfirst($name);
    my @files = @$ref_files;
    my @files_description = @$ref_files_description;
    my $nfiles = @files;
    my $dec = "  ${ucf_name}Output::${ucf_name}Output() {\n";
    for (my $i=0; $i < $nfiles; $i++) {
        $dec .= "    declare('file_$files[$i]', &file_$files[$i], 300, '$files_description[$i]')\n";
    }
    $dec .= qq{  \}
  
  ProfoundOutput::~ProfoundOutput() \{
  \}
};
}

#########################################
### function to initialize the output ###
#########################################
sub init_output($$$$) {
    my $name        = shift;
    my $ref_files   = shift;
    my $ref_columns = shift;
    my $use_tables  = shift;
    
    my $ucf_name = ucfirst($name);
    my @files = @$ref_files;
    my $init = "  void ${ucf_name}Output::init() {\n";

    if ($use_tables) {
        $init .= qq{    define_output_tables();
  \}
  void ${ucf_name}Output::define_output_tables() \{
    std::vector<std::string> pfts;
    pftlist.firstobj();
    while (pftlist.isobj) \{
      Pft& pft=pftlist.getobj();
      pfts.push_back((char*)pft.name);
      pftlist.nextobj();
    \}
    std::vector<std::string> landcovers;
    if (run_landcover) \{
      const char* landcover_string[]={'Urban_sum', 'Crop_sum', 'Pasture_sum', 'Forest_sum', 'Natural_sum', 'Peatland_sum'};
      for (int i=0; i<NLANDCOVERTYPES; i++) \{
        if (run[i]) \{
          landcovers.push_back(landcover_string[i]);
        \}
      \}
    \}
    ColumnDescriptors month_columns;
    ColumnDescriptors month_columns_wide;
    xtring months[] = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
    for (int i = 0; i < 12; i++) \{
      month_columns      += ColumnDescriptor(months[i], 8,  3);
      month_columns_wide += ColumnDescriptor(months[i], 10, 3);
    \}
};
        
        $init .= "  }\n";


    } else {
        while (@files) {
            my $fname = shift(@files);
            $init .= qq{    if (file_${fname} != "") \{
      std::string full_path = (char*) file_${fname};
      out_${fname} = fopen(full_path.c_str(), "w");
      if (out_${fname} == NULL) \{
        fail("Could not open %s for output\\n"\\
             "Close the file if it is open in another application",
             full_path.c_str());
      \} else \{
};

            $init .= column_definition($fname, @${ref_columns{$fname}}, $use_tables);
#        fprintf(out_${fname}, "Lon Lat Year ENTER THE COLUMN DEFINITIONS HERE\n");

            $init .= qq{      \}
    \}
};
        }
        $init .= "  }\n";
    }
    return($init);
}

#####################################
#####################################
#####################################
my $dom        = XML::LibXML->load_xml(location => $fname);
my $name       = $dom->findnodes('/GuessOutput/name')->to_literal();
my $long_name  = $dom->findnodes('/GuessOutput/long_name')->to_literal();
my $use_tables = $dom->findnodes('/GuessOutput/use_tables')->to_literal();
my $author     = $dom->findnodes('/GuessOutput/author')->to_literal();

my @files = ();
my @files_description = ();
my %columns = ();

foreach my $file ($dom->findnodes('/GuessOutput/file')) {
    my $foutname = $file->findvalue('./name');
    push(@files, $foutname);
    push(@files_description, $file->findvalue('./description'));
    
    my @columns = $file->findnodes('./column');
    $columns{$foutname} = \@columns;
}
#######################################################
### create the output files in the current work dir ###
#######################################################
open(HEADEROUT, "> ${name}output.h");
print HEADEROUT header($name, $long_name, $author, "h");
print HEADEROUT declare(\@files, $use_tables);
print HEADEROUT tail($name, "h");
close HEADEROUT;

open(CPPOUT, "> ${name}output.cpp");
print CPPOUT header($name, $long_name, $author, "cpp");
print CPPOUT declare_ins($name, \@files, \@files_description);
print CPPOUT init_output($name, \@files, \%columns, $use_tables);
print CPPOUT tail($name, "cpp");
close CPPOUT;
