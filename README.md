# newOutputModule4LPJGUESS

Perl script to create a new template for an output module (header and C++ code) for the Dynamic Global Vegetation Model LPJ-GUESS. The files need to be 'registered' in the CMakeList.txt file to be build and linked into the model binary.

The information needed to build the files must be in an XML file read by the XML::LibXML module. See profound.xml and climate.xml for examples.

## TODO

* extend 'Table' output
* daily output not yet implemented
