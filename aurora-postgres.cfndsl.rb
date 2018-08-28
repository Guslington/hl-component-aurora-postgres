CloudFormation do

  Description "#{component_name} - #{component_version}"

  Condition("EnableReader", FnEquals(Ref("EnableReader"), 'true'))
  az_conditions_resources('SubnetPersistence', maximum_availability_zones)

  tags = []
  tags << { Key: 'Environment', Value: Ref(:EnvironmentName) }
  tags << { Key: 'EnvironmentType', Value: Ref(:EnvironmentType) }

  extra_tags.each { |key,value| tags << { Key: key, Value: value } } if defined? extra_tags

  EC2_SecurityGroup(:SecurityGroup) do
    VpcId Ref('VPCId')
    GroupDescription FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'security group' ])
    SecurityGroupIngress sg_create_rules(security_group, ip_blocks)
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'security-group' ])}]
  end

  RDS_DBSubnetGroup(:DBClusterSubnetGroup) {
    SubnetIds az_conditional_resources('SubnetPersistence', maximum_availability_zones)
    DBSubnetGroupDescription FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'subnet group' ])
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'subnet-group' ])}]
  }

  RDS_DBClusterParameterGroup(:DBClusterParameterGroup) {
    Description FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'cluster parameter group' ])
    Family 'aurora-postgresql'
    Parameters cluster_parameters if defined? cluster_parameters
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'cluster-parameter-group' ])}]
  }

  RDS_DBCluster(:DBCluster) {
    Engine 'aurora-postgresql'
    DBClusterParameterGroupName Ref(:DBClusterParameterGroup)
    SnapshotIdentifier Ref(:SnapshotID)
    DBSubnetGroupName Ref(:DBClusterSubnetGroup)
    VpcSecurityGroupIds [ Ref(:SecurityGroup) ]
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'cluster' ])}]
  }

  RDS_DBParameterGroup(:DBInstanceParameterGroup) {
    Description FnJoin(' ', [ Ref(:EnvironmentName), component_name, 'instance parameter group' ])
    Family 'aurora-postgresql9.6'
    Parameters instance_parameters if defined? instance_parameters
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'instance-parameter-group' ])}]
  }

  RDS_DBInstance(:DBClusterInstanceWriter) {
    DBSubnetGroupName Ref(:DBClusterSubnetGroup)
    DBParameterGroupName Ref(:DBInstanceParameterGroup)
    DBClusterIdentifier Ref(:DBCluster)
    Engine 'aurora-postgresql'
    PubliclyAccessible 'false'
    DBInstanceClass Ref(:WriterInstanceType)
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'writer-instance' ])}]
  }

  RDS_DBInstance(:DBClusterInstanceReader) {
    Condition(:EnableReader)
    DBSubnetGroupName Ref(:DBClusterSubnetGroup)
    DBParameterGroupName Ref(:DBInstanceParameterGroup)
    DBClusterIdentifier Ref(:DBCluster)
    Engine 'aurora-postgresql'
    PubliclyAccessible 'false'
    DBInstanceClass Ref(:ReaderInstanceType)
    Tags tags + [{ Key: 'Name', Value: FnJoin('-', [ Ref(:EnvironmentName), component_name, 'reader-instance' ])}]
  }

  Route53_RecordSet(:DBHostRecord) {
    HostedZoneName FnJoin('', [ Ref('EnvironmentName'), '.', Ref('DnsDomain'), '.'])
    Name FnJoin('', [ hostname, '.', Ref('EnvironmentName'), '.', Ref('DnsDomain'), '.' ])
    Type 'CNAME'
    TTL '60'
    ResourceRecords [ FnGetAtt('DBCluster','Endpoint.Address') ]
  }

end
