FROM ubuntu:latest

MAINTAINER Raymond Barbiero <raymond.barbiero.dev@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES 1

# Nokogiri dependencies
RUN true \
 && apt-get update \
 && apt-get install -qy --force-yes git ruby ruby-dev build-essential \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN true \
 && apt-get update \
 && apt-get install -qy libxslt1-dev libxml2-dev libssl-dev libyaml-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN true \
 && apt-get update \
 && apt-get install -qy --no-install-recommends openjdk-8-jdk openjdk-8-jre gradle \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN true \
 && apt-get update \
 && apt-get install -qy vim curl lsof libxml2 libxml2-dev pkg-config \
 && apt-get clean \
 && gem install bundler nokogiri \
 && rm -rf /var/lib/apt/lists/*

RUN true \
 && git clone https://github.com/jenkinsci/job-dsl-plugin.git /jdsl \
 && cd /jdsl \
 && gradle :job-dsl-core:oneJar

ENV DSL_JAR "/jdsl/job-dsl-core/build/libs/job-dsl-core-*-standalone.jar"

ENV APP_HOME /app
ENV HOME /root
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
COPY Gemfile* $APP_HOME/
RUN bundle config --global silence_root_warning 1 \
 && bundle install

# Upload source
COPY . $APP_HOME

# Start server
ENV PORT 3000
EXPOSE 3000

VOLUME ["/var/www/uploads"]
CMD ["ruby", "server.rb"]
