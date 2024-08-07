FROM ruby:3.2.2-slim

RUN apt-get update && \
    apt-get install -y make git libsqlite3-dev libxslt-dev libxml2-dev zlib1g-dev gcc g++ && \
    apt-get clean

WORKDIR /oxml_xxe

# Copy and install deps
COPY . .
RUN bundle install

EXPOSE 4567
CMD ["bundle", "exec", "ruby", "server.rb", "-o", "0.0.0.0", "-p", "4567"]
