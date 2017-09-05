web: ps -ef | grep thin | grep -v grep
web: bundle exec thin -p 3000 -P tmp/pids/thin.pid -l logs/thin.log -d start
web: bundle exec rackup config.ru -p 3000
