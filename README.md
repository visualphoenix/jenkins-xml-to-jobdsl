# jenkins-xml-to-jobdsl
Translates jenkins xml jobs into jobdsl groovy

docker build -t jdsl .
docker run -it --rm -v $PWD:$PWD -w $PWD --name jdsl jdsl bash

inside the container, run: ruby jenkins-xml-to-jobdsl.rb tests/pipeline-example/config.xml
