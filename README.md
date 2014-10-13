# Ayouken API


## Requirements

* [Ruby](https://www.ruby-lang.org) (current Gemfile version is 2.1.2)
* [Bundler](http://bundler.io) (`$ gem install bundler`)

You will need a Twitter App to make this bot work as one of the feature is to interact with Twitter API. To do so, please check [this page](https://apps.twitter.com/app/new) out and create your own Twitter application.


## Install

```bash
$ git clone https://github.com/rhannequin/ayouken-api.git
$ cd ayouken-api
$ bundle install
$ cp config.example.yml config.yml
```

Then edit `config.yml` file to put your own configuration.


## Launch

```bash
$ bundle exec foreman start
```

By default, the server is launched on port 5000, so you can visit [localhost:5000](http://localhost:5000).


## Testing

`TODO`
