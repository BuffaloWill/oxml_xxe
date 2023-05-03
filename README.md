# oxml_xxe
This tool is meant to help test XXE vulnerabilities in **OXML document** file formats. Currently supported:

- DOCX/XLSX/PPTX
- ODT/ODG/ODP/ODS
- SVG
- XML

BH USA 2015 Presentation: [Exploiting XXE in File Upload Functionality (Slides)](http://oxmlxxe.github.io/reveal.js/slides.html#/) [(Recorded Webcast)](https://www.blackhat.com/html/webcast/11192015-exploiting-xml-entity-vulnerabilities-in-file-parsing-functionality.html)

Blog Posts on the topic:

- [Exploiting XXE Vulnerabilities in OXML Documents](http://www.silentrobots.com/blog/2015/03/04/oxml_xxe/)
- [Exploiting CVE-2016-4264 With OXML_XXE](https://www.silentrobots.com/blog/2016/10/02/exploiting-cve-2016-4264-with-oxml-xxe/)

# Developer Build

OXML_XXE was re-written in Ruby using Sinatra, Bootstrap, and Slim. Installation should be easy with Docker:

## Docker

1. Run `docker build --tag oxml_xxe .`
2. Run `docker run --name oxml_xxe -p 4567:4567 --rm oxml_xxe`
2. Browse to http://localhost:4567/ to get started.

## Docker Compose
1. Run `docker-compose up`
2. Browse to http://localhost:4567/ to get started.

# Main Modes

**1. Build a File**

Build mode adds a `DOCTYPE` and inserts the XML Entity into the file of the users choice.

**2. String Replace in File**

String replacement mode goes through and looks for the symbol `§` in the document. The XML Entity ("&xxe;") replaces any instances of this symbol. Note, you can open the document in and insert `§` anywhere to have it replaced. The common use case would be a web application which reads in a `xlsx` and then prints the results to the screen. Exploiting the XXE it would be possible to have the contents printed to the screen.
