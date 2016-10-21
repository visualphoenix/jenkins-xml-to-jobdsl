# jenkins-xml-to-jobdsl
Translates jenkins xml jobs into jobdsl groovy

## Building

    docker build -t jdsl .

## Manual invocation

Enter the container:

    docker run -it --rm -v $PWD:$PWD -w $PWD --name jdsl jdsl bash

Inside the container, run:

    ruby jenkins-xml-to-jobdsl.rb tests/pipeline-example/config.xml

## Translation as a service

Start the container:

    docker run -d --name jdsl -p 3000:3000 jdsl

Upload a job for translation:

    curl \
      -F file=@"$PWD/tests/pipeline-example/config.xml" \
      -F name='pipeline-example' \
      http://localhost:3000
