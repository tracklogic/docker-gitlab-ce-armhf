FROM armv7/armhf-ubuntu
RUN apt update
RUN apt-get install -y ruby git logrotate libxml2 cmake pkg-config openssl libicu55 python2.7 python-setuptools curl golang postgresql sudo redis-server vim ruby-dev libicu-dev libpq-dev libv8-dev libv8-3.14.5 ruby-execjs nginx expect
#RUN ln -s /usr/bin/python2.7 /usr/bin/python2
RUN easy_install pip
RUN pip install pygments
RUN curl -O http://heanet.dl.sourceforge.net/project/docutils/docutils/0.12/docutils-0.12.tar.gz && gunzip -c docutils-0.12.tar.gz | tar xopf - && cd docutils-0.12 && python setup.py install
RUN useradd git
RUN mkdir /home/git
RUN chown -R git:git /home/git
RUN service postgresql start
RUN sudo -u postgres -i psql -d postgres -c "CREATE USER git;"
RUN sudo -u postgres -i psql -d postgres -c "CREATE DATABASE gitlabhq_production OWNER git;"
RUN sudo -u postgres -i psql -d postgres -c "GRANT ALL PRIVILEGES ON  DATABASE gitlabhq_production to git;"
RUN sudo -u postgres -i psql -d postgres -c "ALTER USER git CREATEDB;"
RUN sudo -u postgres -i psql -d postgres -c "ALTER DATABASE gitlabhq_production owner to git;"
RUN sudo -u postgres -i psql -d postgres -c "ALTER USER myuser WITH SUPERUSER;"
RUN cp /etc/redis/redis.conf /etc/redis/redis.conf.bak
RUN sed 's/^port .*/port 0/' /etc/redis/redis.conf.bak | sed 's/# unixsocket/unixsocket/' | sed 's/unixsocketperm 700/unixsocketperm 777/' | tee /etc/redis/redis.conf
RUN service redis-server start
RUN sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 8-7-stable gitlab
RUN sudo -u git -H cp /home/git/gitlab/config/gitlab.yml.example /home/git/gitlab/config/gitlab.yml
RUN sudo -u git -H cat /home/git/gitlab/config/gitlab.yml.example | sed 's/port: 80 /port: 8080 /' | tee /home/git/gitlab/config/gitlab.yml
RUN mkdir /home/git/repositories
RUN sudo -u git -H cp /home/git/gitlab/config/secrets.yml.example /home/git/gitlab/config/secrets.yml
RUN sudo -u git -H chmod 0600 /home/git/gitlab/config/secrets.yml
RUN sudo chown -R git /home/git/gitlab/log/
RUN sudo chown -R git /home/git/gitlab/tmp/
RUN sudo chmod -R u+rwX,go-w /home/git/gitlab/log/
RUN sudo chmod -R u+rwX /home/git/gitlab/tmp/
RUN sudo chmod -R u+rwX /home/git/gitlab/tmp/pids/
RUN sudo chmod -R u+rwX /home/git/gitlab/tmp/sockets/
RUN mkdir /home/git/gitlab/public/uploads
RUN chown -R git:git /home/git
RUN sudo chmod 0700 /home/git/gitlab/public/uploads
RUN sudo chmod -R u+rwX /home/git/gitlab/builds/
RUN sudo -u git -H cp /home/git/gitlab/config/unicorn.rb.example /home/git/gitlab/config/unicorn.rb
RUN sudo -u git -H cp /home/git/gitlab/config/initializers/rack_attack.rb.example /home/git/gitlab/config/initializers/rack_attack.rb
RUN sudo -u git -H git config --global core.autocrlf input
RUN sudo -u git -H git config --global gc.auto 0
RUN sudo -u git -H cat /home/git/gitlab/config/resque.yml.example | sed 's/unix:\/var\/run\/redis\/redis.sock/unix:\/tmp\/redis.sock/' | tee /home/git/gitlab/config/resque.yml
RUN sudo -u git -H cat /home/git/gitlab/config/database.yml.postgresql | head -n 8 | sed 's/pool: 10/pool: 10\n  template: template0/' | tee /home/git/gitlab/config/database.yml
RUN sudo -u git -H chmod o-rwx /home/git/gitlab/config/database.yml
RUN mkdir /var/lib/gems
RUN chown -R git:git /var/lib/gems/
RUN gem install bundler --no-ri --no-rdoc
RUN gem install therubyracer
RUN gem install therubyrhino
RUN cd /home/git/gitlab && sudo -u git -H bundle install --deployment --without development test mysql aws kerberos
RUN cd /home/git/gitlab && sudo -u git -H bundle exec rake gitlab:shell:install[v2.7.2] REDIS_URL=unix:/tmp/redis.sock RAILS_ENV=production
RUN cd /home/git && sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-workhorse.git && cd gitlab-workhorse && git checkout branch-0.7.1 && make
#possibly not needed, but let's be sure it works
RUN sudo -u postgres -H psql -d gitlabhq_production -c "CREATE EXTENSION pg_trgm;"
RUN cd /home/git/gitlab && sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production
#silent setup, thanks to athiele (https://github.com/mattias-ohlsson/gitlab-installer/issues/31)
RUN cd /home/git/gitlab && sudo -u git -H expect -c \"spawn bundle exec rake gitlab:setup RAILS_ENV=production; expect \\"Do you want to continue (yes/no)?\\"; send \\"yes\\";\"
RUN cp /home/git/gitlab/lib/support/init.d/gitlab /etc/init.d/gitlab
RUN cd /home/git/gitlab && sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production
RUN cd /home/git/gitlab && sudo -u git -H bundle exec rake assets:precompile RAILS_ENV=production
RUN cat /home/git/gitlab/lib/support/nginx/gitlab | sed 's/server_name YOUR_SERVER_FQDN;/server_name $HOSTNAME;/' | tee /etc/nginx/sites-enabled/gitlab
RUN rm -f /etc/nginx/sites-enabled/default