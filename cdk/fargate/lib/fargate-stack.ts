import { Stack, StackProps, aws_ec2 as ec2, aws_ecs as ecs, aws_ecs_patterns as ecs_patterns } from 'aws-cdk-lib';
import { Construct } from 'constructs';

export class FargateStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'MainVPC', {
      ipAddresses: ec2.IpAddresses.cidr('10.0.0.0/16'),
      maxAzs: 2,
      subnetConfiguration: [
        {
          cidrMask: 24,
          name: 'public',
          subnetType: ec2.SubnetType.PUBLIC,
        },
        {
          cidrMask: 28,
          name: 'private',
          subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS,
        }
      ]
    });

    const cluster = new ecs.Cluster(this, 'Cluster', {
      vpc: vpc,
    });

    const taskDefinition = new ecs.FargateTaskDefinition(this, 'TaskDefinition', {
      memoryLimitMiB: 512,
      cpu: 256,
    });

    taskDefinition.addContainer('exampleContainer', {
      image: ecs.ContainerImage.fromRegistry('yeasy/simple-web:latest'),
      memoryLimitMiB: 512,
      logging: new ecs.AwsLogDriver({
        streamPrefix: 'ecs-fargate',
      }),
      portMappings: [{
        containerPort: 80,
      }]
    })

    new ecs_patterns.ApplicationLoadBalancedFargateService(this, 'Service', {
      cluster: cluster,
      taskDefinition: taskDefinition,
      desiredCount: 1,
      publicLoadBalancer: true,
      taskSubnets: {
        subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS
      },
      listenerPort: 80,
      assignPublicIp: true,
    });
  }
}