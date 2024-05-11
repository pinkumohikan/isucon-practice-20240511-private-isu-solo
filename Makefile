.PHONY: *

gogo: stop-services build truncate-logs start-services bench

stop-services:
	sudo systemctl stop nginx
	sudo systemctl stop isu-go
	sudo systemctl stop mysql

build:
	. ~/env.sh && cd webapp/golang/ && make app

truncate-logs:
	sudo journalctl --vacuum-size=1K
	sudo truncate --size 0 /var/log/nginx/access.log
	sudo truncate --size 0 /var/log/nginx/error.log
	sudo truncate --size 0 /var/log/mysql/mysql-slow.log && sudo chmod 666 /var/log/mysql/mysql-slow.log
	sudo truncate --size 0 /var/log/mysql/error.log

start-services:
	sudo systemctl start mysql
	sudo systemctl start isu-go
	sudo systemctl start nginx

alp:
	([ -e /tmp/alp-dump.yaml ] && sudo cp /tmp/alp-dump.yaml /tmp/alp-dump.old.yaml) || touch /tmp/alp-dump.old.yaml
	sudo cat /var/log/nginx/access.log | alp json --matching-groups="/image/[0-9]+.(png|jpg|gif)","/@[\w]+","/posts/[\d]+" --dump /tmp/alp-dump.yaml >/dev/null
	alp diff --sort sum --reverse /tmp/alp-dump.old.yaml /tmp/alp-dump.yaml --format=markdown -o count,sum,avg,stddev,min,p99,max,2xx,3xx,4xx,5xx,method,uri | head -n 20

pprof: TIME=60
pprof: PROF_FILE=~/pprof.samples.$(shell TZ=Asia/Tokyo date +"%H%M").$(shell git rev-parse HEAD | cut -c 1-8).pb.gz
pprof:
	curl -sSf "http://localhost:6060/debug/fgprof?seconds=$(TIME)" > $(PROF_FILE)
	go tool pprof $(PROF_FILE)

bench:
	ssh isucon-bench "~/private_isu.git/benchmarker/bin/benchmarker -u ~/private_isu.git/benchmarker/userdata -t http://172.31.20.1"
