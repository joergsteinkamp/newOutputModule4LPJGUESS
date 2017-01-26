#!/usr/bin/env perl

use warnings;
use strict;
use XML::LibXML;
### http://grantm.github.io/perl-libxml-by-example/basics.html

my $fname = shift;

############################################################
### function returning the beginning of the source files ###
###  .h .cpp                                             ###
############################################################
sub head($$$$) {
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
###############################################
### function to declare the output variable ###
### .h                                      ###
###############################################
sub declare($$) {
    my $ref_files = shift;
    my $use_tables = shift;
    my @files = @$ref_files;
    my $declaration = "";
    $declaration = "    void define_output_tables();\n" if ($use_tables);
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
### .cpp                                    ###
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
### .cpp                              ###
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
    // create a vector with the pft names
    std::vector<std::string> pfts;
    pftlist.firstobj();
    while (pftlist.isobj) \{
      Pft& pft=pftlist.getobj();

      pfts.push_back((char*)pft.name);
      pftlist.nextobj();
    \}
    ColumnDescriptors month_columns;
    ColumnDescriptors month_columns_wide;
    xtring months[] = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
    for (int i = 0; i < 12; i++) \{
      month_columns      += ColumnDescriptor(months[i], 8,  3);
      month_columns_wide += ColumnDescriptor(months[i], 10, 3);
    \}
    // pfts
    ColumnDescriptors pft_columns;
    pft_columns += ColumnDescriptors(pfts, 8, 3);
    pft_columns += ColumnDescriptor("Total", 8, 3);
    ColumnDescriptors pft_columns_wide;
    cmass_columns_wide += ColumnDescriptors(pfts, 10, 3);
    cmass_columns_wide += ColumnDescriptor("Total", 10, 3);

};
        while (@files) {
            my $file = shift(@files);
            my $file_name = $file->findnodes('./name');
            my $template  = $file->findnodes('./template');
            $init .= "    create_output_table(out_$file_name, file_$file_name, $template);\n";
        }
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
######################################################
### function returning the tail of the sorce files ###
### .h .cpp                                        ###
######################################################
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
*/
    int m;\n
    if (date.year >= nyear_spinup) \{
};
        if ($use_tables) {
          $tail .= qq{      double lon = gridcell.get_lon();
      double lat = gridcell.get_lat();
      OutputRows out(output_channel, lon, lat, date.get_calendar_year());
};
}
        @files = @$ref_files;
        while(@files) {
            my $dom = shift(@files);
            my $file_name = $dom->findvalue('./name');
            if ($use_tables) {
                my $template = $dom->findvalue('./template');
                my $cname = $dom->findvalue('./cname');
                $cname = "XXX" if (!$cname);
                if ($template =~ /month/) {
                    $tail .= "      for (m=0;m<12;m++) {\n        out.add_value(out_$file_name, $cname\[m\]);\n      }\n";
                } else {
                    $tail .= "      out.add_value(out_$file_name, $cname);\n";
                }
            } else {
                next if ($dom->findvalue('daily') ne "0");
                my @nodes = $dom->findnodes("./column");
                while (@nodes) {
                    my $column = shift(@nodes);
                    ## results in a warning if 'cname' does not exist.
                    my $cname = uc("${file_name}.$column->{name}");
                    $cname = $column->{cname} if (grep(/^cname$/, keys %$column));
                    if ($column->{'type'} eq "s" || $column->{'type'} eq "i") {
                        $tail .= "      fprintf(out_${file_name}, ' %$column->{length}$column->{type}', $cname);\n";
                    } else {
                        $tail .= "      fprintf(out_${file_name}, ' %$column->{length}.$column->{dec}$column->{type}', $cname);\n";
                    }
                }
            }
        }
        $tail .= qq{    \}
    return;
  \}
\}
};
    } elsif ($suffix eq "h") {
        $tail = qq{  \};
\}
#endif
};
    }
    return($tail);
}

###############################
### END function definition ###
###############################

## read the XML input
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
print HEADEROUT head($name, $long_name, $author, "h");
print HEADEROUT declare(\@files, $use_tables);
print HEADEROUT tail($name, "h");
close HEADEROUT;

open(CPPOUT, "> ${name}output.cpp");
print CPPOUT head($name, $long_name, $author, "cpp");
print CPPOUT declare_ins($name, \@files);
print CPPOUT init_output($name, \@files, $use_tables);
print CPPOUT tail($name, "cpp", \@files, $use_tables);
close CPPOUT;
