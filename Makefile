.PHONY: up down restart logs build stop pull help

help:
	@echo "Available commands:"
	@echo "  make up       - Start all containers"
	@echo "  make down     - Stop and remove all containers"
	@echo "  make restart  - Restart all containers"
	@echo "  make logs     - View logs from all containers"
	@echo "  make build    - Build all images"
	@echo "  make stop     - Stop all containers"
	@echo "  make pull     - Pull latest images"

up:
	docker-compose up -d

down:
	docker-compose down

restart:
	docker-compose restart

logs:
	docker-compose logs -f

build:
	docker-compose build

stop:
	docker-compose stop

pull:
	docker-compose pull

migrate:                                                                                           
		docker-compose exec app python manage.py migrate                                               
																																																		
shell:                                                                                             
		docker-compose exec app python manage.py shell                                                 
																																																		
test-be:                                                                                           
		docker-compose exec app pytest                                                                 
																																																		
logs-app:                                                                                          
		docker-compose logs -f app  