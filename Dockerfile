FROM ubuntu:latest

MAINTAINER Ryan Grothouse <rgrothouse@gmail.com>

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
