FROM armv7/armhf-ubuntu
RUN apt update
RUN apt-get install -y ruby git logrotate libxml2 cmake pkg-config openssl libicu55 python2.7 python-setuptools curl golang postgresql sudo redis-server vim ruby-dev libicu-dev libpq-dev libv8-dev libv8-3.14.5 ruby-execjs nginx
RUN ln -s /usr/bin/python2.7 /usr/bin/python2
RUN easy_install pip
RUN pip install pygments
RUN curl -O http://heanet.dl.sourceforge.net/project/docutils/docutils/0.12/docutils-0.12.tar.gz && gunzip -c docutils-0.12.tar.gz | tar xopf - && cd docutils-0.12 && python setup.py install
