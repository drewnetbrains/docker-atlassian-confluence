require 'timeout'
require 'spec_helper'

describe 'Atlassian Confluence with Embedded Database', order: :defined do

	include_examples 'a buildable docker image', '.', { env: ["CATALINA_OPTS=-Xms2048m -Xmx3072m -Datlassian.plugins.enable.wait=#{Docker::DSL.timeout}"] }

	include_examples 'an acceptable confluence instance', 'using an embedded database'

end

describe 'Atlassian Confluence with PostgreSQL 9.3 Database', order: :defined do

	include_examples 'a buildable docker image', '.', { env: ["CATALINA_OPTS=-Xms2048m -Xmx3072m -Datlassian.plugins.enable.wait=#{Docker::DSL.timeout}"] }

	include_examples 'an acceptable confluence instance', 'using a postgresql database' do
		before :all do
      Docker::Image.create fromImage: 'postgres:9.3'
      # Create and run a PostgreSQL 9.3 container instance
      @container_db = Docker::Container.create image: 'postgres:9.3'
      @container_db.start!
      # Wait for the PostgreSQL instance to start
      @container_db.wait_for_output %r{PostgreSQL\ init\ process\ complete;\ ready\ for\ start\ up\.}
      # Create Confluence database
      if ENV['CIRCLECI']
        %x( docker run --link "#{@container_db.id}:db" postgres:9.3 psql --host "db" --user "postgres" --command "create database confluencedb owner postgres encoding 'utf8';" )
      else
        @container_db.exec ["psql", "--username", "postgres", "--command", "create database confluencedb owner postgres encoding 'utf8';"]
      end
    end
    after :all do
      @container_db.remove force: true, v: true unless @container_db.nil? || ENV['CIRCLECI']
    end
	end
end

describe 'Atlassian Confluence with MySQL 5.6 Database', order: :defined do

	include_examples 'a buildable docker image', '.', { env: ["CATALINA_OPTS=-Xms2048m -Xmx3072m -Datlassian.plugins.enable.wait=#{Docker::DSL.timeout}"] }

	include_examples 'an acceptable confluence instance', 'using a mysql database' do
		before :all do
			Docker::Image.create fromImage: 'mysql:5.6'
			# Create and run a MySQL 5.6 container instance
			@container_db = Docker::Container.create image: 'mysql:5.6', env: ['MYSQL_ROOT_PASSWORD=mysecretpassword']
			@container_db.start!
			# Wait for the MySQL instance to start
			@container_db.wait_for_output %r{socket:\ '/var/run/mysqld/mysqld\.sock'\ \ port:\ 3306\ \ MySQL\ Community\ Server\ \(GPL\)}
			# Create Confluence database
			if ENV['CIRCLECI']
				%x( docker run --link "#{@container_db.id}:db" mysql:5.6 mysql --host "db" --user=root --password=mysecretpassword --execute 'CREATE DATABASE confluencedb CHARACTER SET utf8 COLLATE utf8_bin;' )
			else
				@container_db.exec ['mysql', '--user=root', '--password=mysecretpassword', '--execute', 'CREATE DATABASE confluencedb CHARACTER SET utf8 COLLATE utf8_bin;']
			end
		end
		after :all do
			@container_db.remove force: true, v: true unless @container_db.nil? || ENV['CIRCLECI']
		end
	end
end

describe 'Atlassian Confluence behind reverse proxy', order: :defined do

	include_examples 'a buildable docker image', '.', {
		env: [
			"CATALINA_OPTS=-Xms2048m -Xmx3072m -Datlassian.plugins.enable.wait=#{Docker::DSL.timeout}",
			"X_PROXY_NAME=#{Docker.info['Name']}",
			'X_PROXY_PORT=80',
			'X_PROXY_SCHEME=http',
			'X_PATH=/confluence'
		]
	} do
		before :all do
			Docker::Image.create fromImage: 'blacklabelops/nginx:latest'
			# Create and run a nginx reverse proxy container instance
			@container_proxy = Docker::Container.create image: 'blacklabelops/nginx:latest',
				PortBindings: { '8080/tcp': [{ 'HostPort': '80' }] },
				Links: ["#{@container.id}:container"],
				env: ['SERVER1REVERSE_PROXY_LOCATION1=/confluence/', 'SERVER1REVERSE_PROXY_PASS1=http://container:8090/confluence/']
			@container_proxy.start!
			@container_proxy.setup_capybara_url({ tcp: 8080 }, '/confluence/')
		end
		after :all do
			@container_proxy.remove force: true, v: true unless @container_proxy.nil? || ENV['CIRCLECI']
		end
	end

	include_examples 'a minimal acceptable confluence instance', 'using an embedded database'

end
