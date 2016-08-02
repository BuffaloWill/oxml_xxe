# oxml_xxe
This tool is meant to help test XXE vulnerabilities in ~~OXML document~~ file formats. Currently supported:

- DOCX/XLSX/PPTX
- ODT/ODG/ODP/ODS
- SVG
- XML
- PDF (experimental)
- JPG (experimental)
- GIF (experimental)

BH USA 2015 Presentation:

[Exploiting XXE in File Upload Functionality (Slides)](http://oxmlxxe.github.io/reveal.js/slides.html#/) [(Recorded Webcast)](https://www.blackhat.com/html/webcast/11192015-exploiting-xml-entity-vulnerabilities-in-file-parsing-functionality.html)

Blog Posts on the topic:

[Exploiting XXE Vulnerabilities in OXML Documents - Part 1](http://www.silentrobots.com/blog/2015/03/04/oxml_xxe/)

# Developer Build

OXML_XXE was re-written in Ruby using Sinatra, Bootstrap, and Haml. Installation should be easy:

- You will need a copy of Ruby. RVM is suggested (https://rvm.io/rvm/install). ruby version 2.1.5 is supported.

```
rvm install 2.1.5
rvm use 2.1.5
```

- If you are running Ubuntu (or also verified on Kali) you will need a couple of dependencies:
```
apt-get install libsqlite3-dev libxslt-dev libxml2-dev zlib1g-dev gcc
```

```
cd oxml_xxe
gem install bundler
bundle install
ruby server.rb
```

# Main Modes

There are two main modes:

## Build a File

Build mode adds a DOCTYPE and inserts the XML Entity into the file of the users choice.

## String Replace in File

String replacement mode goes through and looks for the symbol § in the document. The XML Entity ("&xxe;") replaces any instances of this symbol. Note, you can open the document in and insert § anywhere to have it replaced. The common use case would be a web application which reads in a xlsx and then prints the results to the screen. Exploiting the XXE it would be possible to have the contents printed to the screen.

