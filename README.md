# oxml_xxe
This tool is meant to help test XXE vulnerabilities in OXML document formats.

BH USA 2015 Presenetation:
[Exploiting XXE in File Upload Functionality](http://oxmlxxe.github.io/reveal.js/slides.html#/)

Blog Posts on the topic:

[Exploiting XXE Vulnerabilities in OXML Documents - Part 1](http://www.silentrobots.com/blog/2015/03/04/oxml_xxe/)

# Quick Examples

## Build a PDF with XXE in XMP (metadata)
```
ruby oxml_xxe.rb --poc pdf -i 192.168.14.1:8000
```

# Main Modes

There are two main modes:

## Build Mode ("-b")

Build mode adds a DOCTYPE and inserts the XML Entity into the file of the users choice.

## String Replacement Mode ("-s")

String replacement mode goes through and looks for the symbol § in the document. The XML Entity ("&xxe;") replaces any instances of this symbol. Note, you can open the document in and insert § anywhere to have it replaced. The common use case would be a web application which reads in a xlsx and then prints the results to the screen. Exploiting the XXE it would be possible to have the contents printed to the screen.

