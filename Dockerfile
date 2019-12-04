FROM ruby:2.6.5

RUN gem install bundler:2.0.2
RUN bundle config --global frozen 1

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY entrypoint.sh /entrypoint.sh
COPY action.rb /action.rb
COPY lib /lib

RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
