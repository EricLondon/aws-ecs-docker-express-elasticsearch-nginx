#!/usr/bin/env ruby

require 'json'
require 'yaml'

FAMILY = 'eric-test-family'
IMAGE = '############.dkr.ecr.us-east-1.amazonaws.com/eric-test/'

docker_compose_file = './docker-compose.yml'
cloudformation_file = './aws/cloud-formation-task.json'
raise 'Docker compose file not found.' unless File.exist?(docker_compose_file)

# skeleton task definition from aws cli
cf_skeleton = JSON.parse(`aws ecs register-task-definition --generate-cli-skeleton`)
cf_skeleton.delete 'placementConstraints'
cf_skeleton.delete 'taskRoleArn'
cf_skeleton.delete 'networkMode'
cf_skeleton['family'] = FAMILY
cf_volume = cf_skeleton['volumes'].pop
cf_container = cf_skeleton['containerDefinitions'].pop
cf_container['command'] = []
cf_container['environment'] = []
cf_container['links'] = []
cf_container['mountPoints'] = []
cf_container['portMappings'] = []

# load docker-compose yaml
docker_compose_data = YAML.load_file docker_compose_file

# transpose shared volumes
volumes_map = {}
docker_compose_data['volumes'].each_with_index do |(key, value), index|
  volume = Marshal.load(Marshal.dump(cf_volume))
  volume['host']['sourcePath'] = key
  volume['name'] = "volume-#{index}"
  cf_skeleton['volumes'] << volume
  volumes_map[key] = "volume-#{index}"
end

# transpose containers
docker_compose_data['services'].each do |service|
  container = Marshal.load(Marshal.dump(cf_container))
  container['name'] = service[0]
  container['image'] = "#{IMAGE}#{service[0]}:latest"

  unless service[1]['volumes'].nil?
    service[1]['volumes'].each do |volume|
      (name, path) = volume.split(':')
      container['mountPoints'] << {
        'sourceVolume' => volumes_map[name],
        'readOnly' => false,
        'containerPath' => path
      }
    end
  end

  unless service[1]['ports'].nil?
    service[1]['ports'].each do |port|
      (host_port, container_port) = port.split(':')
      container['portMappings'] << {
        'protocol' => 'tcp',
        'containerPort' => container_port,
        'hostPort' => host_port,
      }
    end
  end

  unless service[1]['depends_on'].nil?
    service[1]['depends_on'].each do |depends_on|
      container['links'] << depends_on
    end
  end

  unless service[1]['command'].nil?
    container['command'] << service[1]['command']
  end

  unless service[1]['environment'].nil?
    service[1]['environment'].each do |environment|
      (name, value) = environment.split('=')
      container['environment'] << {
        'name' => name,
        'value' => value,
      }
    end
  end

  cf_skeleton['containerDefinitions'] << container
end

File.write(cloudformation_file, JSON.pretty_generate(cf_skeleton))
