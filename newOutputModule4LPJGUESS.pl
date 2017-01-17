#!/usr/bin/env perl

use warnings;
use strict;
use XML::LibXML;

my $fname = shift;

#################################
### Define the output culumns ###
#################################

sub column_output($$$) {
    my $name       = shift;
    my $column_ref = shift;
    my $use_tables = shift;

    my $output_line = "";
    if ($use_tables) {
        die ("JS_DEBUG: 'use_tables' not yet ready!");
    } else {
        my $output_line = join "\n", map {
            "fprintf(out_${name}, ' %$_->{length}.$_->{dev}$_->{type} ', ". uc("${name}.$_->{name});");
        } @$column_ref;
        print($output_line);
    }
    return($output_line);
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
sub tail(@) {
    my $nargs = @_;
    my $name = shift;
    my $suffix = shift;
    die ("Not enough arguments ($nargs) for sub 'tail' with 'suffix = cpp'!") if ($suffix eq "cpp" && $nargs < 4);
    my $ref_files;
    my $use_tables;
    if ($suffix eq "cpp") {
        $ref_files   = shift;
        $use_tables  = shift;
    }
    my $ucf_name = ucfirst($name);
    my $tail;
    if ($suffix eq "cpp") {
        $tail = qq{  void ${ucf_name}Output::outdaily(Gridcell& gridcell) \{
/* DEFINE DAILY OUTPUT HERE
     1.) Create the appropriate stand/patch/vegetation loops around the following fprint statements.
     2.) Replace the uppercase variable names by the correct variable names of the LPJ-GUESS model
*/
};
        my @files = @$ref_files;
        while(@files) {
            my $dom = shift(@files);
            my $file_name = $dom->findvalue('./name');
            next if ($dom->findvalue('daily') eq "0" || !$dom->findvalue('daily'));
            die("JS_DEBUG: daily not yet ready '$file_name'!");
        }

        $tail .= qq{    return;
  \}
  void ${ucf_name}Output::outannual(Gridcell& gridcell) \{
/* DEFINE ANNUAL AND MONTHLY OUTPUT HERE
     1.) Create the appropriate stand/patch/vegetation loops around the following fprint statements.
     2.) Replace the uppercase variable names by the correct variable names of the LPJ-GUESS model
     3.) and uncomment the fprint statements.
*/\n
};
        @files = @$ref_files;
        while(@files) {
            my $dom = shift(@files);
            my $file_name = $dom->findvalue('./name');
            next if ($dom->findvalue('daily') ne "0");
            my @nodes = $dom->findnodes("./column");
            while (@nodes) {
                my $column = shift(@nodes);
                ## results in a warning if 'cname' does not exist.
                my $cname = ($column->{cname} eq "") ? uc("${file_name}.$column->{name}") : $column->{cname};
                print "JS_DEBUG: $cname\n";
                if ($column->{'type'} eq "s" || $column->{'type'} eq "i") {
                    $tail .="    //fprintf(out_${file_name}, ' %$column->{length}$column->{type}', ". uc("${file_name}.$column->{name});\n");
                } else {
                    $tail .= "    //fprintf(out_${file_name}, ' %$column->{length}.$column->{dec}$column->{type}', ". uc("${file_name}.$column->{name});\n");
                }
            }
        }
        $tail .= qq{
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
        die("File suffix '$suffix' unknown!");
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
    my $declaration = "";
    while (@files) {
        my $dom = shift(@files);
        my $file_name = $dom->findvalue('./name');
        $declaration .= "    xtring file_${file_name};\n";
        if ($use_tables) {
            $declaration .= "    Table *out_${file_name};\n";
        } else {
            $declaration .= "    FILE *out_${file_name};\n";
        }
    }
    return($declaration);
}
###############################################
### function to declare ins-file parameters ###
###############################################
sub declare_ins($$) {
    my $name      = shift;
    my $ref_files = shift;
    my $ucf_name  = ucfirst($name);
    my @files = @$ref_files;
    my $dec = "  ${ucf_name}Output::${ucf_name}Output() {\n";
    while(@files) {
        my $dom = shift(@files);
        my $file_name = $dom->findvalue('./name');
        my $file_description = $dom->findvalue('./description');
        $dec .= "    declare('file_$file_name', &file_$file_name, 300, '$file_description');\n";
    }
    $dec .= qq{  \}

  ProfoundOutput::~ProfoundOutput() \{
  \}
};
}

#########################################
### function to initialize the output ###
#########################################
sub init_output($$$) {
    my $name       = shift;
    my $ref_files  = shift;
    my $use_tables = shift;

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
            my $file = shift(@files);
            my $file_name = $file->findnodes('./name');
            $init .= qq{    if (file_${file_name} != "") \{
      std::string full_path = (char*) file_${file_name};
      out_${file_name} = fopen(full_path.c_str(), "w");
      if (out_${file_name} == NULL) \{
        fail("Could not open %s for output\\n"\\
             "Close the file if it is open in another application",
             full_path.c_str());
      \} else \{
};

            if ($use_tables) {
                die ("JS_DEBUG: Table definition not yet ready!");
            } else {
                my $cnames = join ' ', map {
                    $_->{name};
                } $file->findnodes('./column');
                $init .= "        fprintf(out_${file_name}, 'Lon Lat Year ".$cnames."');\n";
            }
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
my @file_names = ();
my @file_descriptions = ();

### output files
foreach my $file ($dom->findnodes('/GuessOutput/file')) {
    push(@files, $file);
    my $file_name = $file->findvalue('./name');
    die("Empty file names not allowed!\n${file}\n") if ($file_name eq "");
    push(@file_names, $file_name);
    push(@file_descriptions, $file->findvalue('./description'));
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
print CPPOUT declare_ins($name, \@files);
print CPPOUT init_output($name, \@files, $use_tables);
print CPPOUT tail($name, "cpp", \@files, $use_tables);
close CPPOUT;
