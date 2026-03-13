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