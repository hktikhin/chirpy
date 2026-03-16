# Install bootdev cli
go install github.com/bootdotdev/bootdev@latest
go mod init github.com/hktikhin/chirpy

sudo apt update
sudo apt install postgresql postgresql-contrib
psql --version
sudo passwd postgres
sudo service postgresql start

sudo -i
sudo -u postgres psql
CREATE DATABASE chirpy;
\c chirpy
ALTER USER postgres WITH PASSWORD 'postgres';

go install github.com/pressly/goose/v3/cmd/goose@latest
go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest

cd sql/schema 
goose postgres "" up && cd ../..

sqlc generate
go get github.com/google/uuid
go get github.com/lib/pq
go get github.com/joho/godotenv