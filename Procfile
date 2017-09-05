web: bundle exec rackup config.ru -p $PORT
web: bundle exec thin -p 3000 -P tmp/pids/thin.pid -l logs/thin.log -d start
web: ps -ef | grep thin | grep -v grep
