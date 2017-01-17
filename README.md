# newOutputModule4LPJGUESS

Perl script to create a new template for an output module (header and C++ code) for the Dynamic Global Vegetation Model LPJ-GUESS. The files need to be 'registered' in the CMakeList.txt file to be build and linked into the model binary.

The information needed to build the files must be in an XML file read by the XML::LibXML module. See profound.xml as example.

# TODO

* standard 'Table' output currently not implemented
* daily output not yet implemented
