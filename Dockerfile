FROM ruby:3.3-slim

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential libpq-dev curl git libyaml-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle install

COPY . .

RUN chmod +x bin/docker-entrypoint

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
