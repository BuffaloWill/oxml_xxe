FROM ruby:2.7.7-slim

RUN apt-get update && \
    apt-get install -y make git libsqlite3-dev libxslt-dev libxml2-dev zlib1g-dev gcc && \
    apt-get clean

WORKDIR /oxml_xxe

# install deps
COPY Gemfile ./
RUN bundle install

COPY . .

EXPOSE 4567
CMD ["bundle", "exec", "ruby", "server.rb", "-o", "0.0.0.0", "-p", "4567"]
