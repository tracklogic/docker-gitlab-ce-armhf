#!/bin/sh
#docker create --name=gitlabce-image -p 8081:80 gitlabce_image 
#docker start gitlabce-image 
# docker run --name gitlabce-image -d gitlabce_image /bin/sh 
docker run -it -d -p 8081:80 gitlabce_image

