const { execSync } = require('child_process');
const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');

// Configure AWS SDK
AWS.config.update({ region: process.env.AWS_REGION || 'us-east-1' });
const ec2 = new AWS.EC2();
const cloudwatch = new AWS.CloudWatch();

// Test configuration
const INFRA_CONFIG = {
  projectName: 'todo-api',
  environment: 'infrastructure-test',
  region: process.env.AWS_REGION || 'us-east-1',
  timeout: 300000 // 5 minutes
};

describe('Infrastructure Validation Tests', () => {
  jest.setTimeout(INFRA_CONFIG.timeout);

  let testResources = {
    instanceId: null,
    securityGroupId: null,
    elasticIp: null,
    volumeId: null
  };

  beforeAll(async () => {
    console.log('Starting infrastructure validation tests...');
    
    // Verify AWS credentials
    await verifyAWSCredentials();
  });

  afterAll(async () => {
    console.log('Infrastructure validation tests completed');
  });

  describe('Terraform Configuration Validation', () => {
    test('should validate Terraform configuration syntax', () => {
      console.log('Validating Terraform configuration...');
      
      const terraformDir = path.join(__dirname, '../../terraform');
      
      // Initialize Terraform
      execSync('terraform init', {
        cwd: terraformDir,
        encoding: 'utf8'
      });
      
      // Validate configuration
      const validateResult = execSync('terraform validate', {
        cwd: terraformDir,
        encoding: 'utf8'
      });
      
      expect(validateResult).toContain('Success');
      console.log('Terraform configuration is valid');
    });

    test('should validate Terraform plan without errors', () => {
      console.log('Creating Terraform plan...');
      
      const terraformDir = path.join(__dirname, '../../terraform');
      
      // Create test variables file
      const testVarsContent = `
project_name     = "${INFRA_CONFIG.projectName}"
environment      = "${INFRA_CONFIG.environment}"
aws_region       = "${INFRA_CONFIG.region}"
instance_type    = "t3.micro"
key_pair_name    = "test-key"
allowed_ssh_cidr = "0.0.0.0/0"
volume_size      = 20
enable_monitoring = true
`;
      
      fs.writeFileSync(path.join(terraformDir, 'test.tfvars'), testVarsContent);
      
      try {
        // Create plan
        const planResult = execSync('terraform plan -var-file=test.tfvars -out=test.tfplan', {
          cwd: terraformDir,
          encoding: 'utf8'
        });
        
        expect(planResult).not.toContain('Error');
        expect(planResult).toContain('Plan:');
        
        console.log('Terraform plan created successfully');
        
      } finally {
        // Clean up test files
        const testFiles = ['test.tfvars', 'test.tfplan'];
        testFiles.forEach(file => {
          const filePath = path.join(terraformDir, file);
          if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
          }
        });
      }
    });

    test('should validate required Terraform variables', () => {
      console.log('Validating Terraform variables...');
      
      const variablesFile = path.join(__dirname, '../../terraform/variables.tf');
      const variablesContent = fs.readFileSync(variablesFile, 'utf8');
      
      // Check for required variables
      const requiredVariables = [
        'project_name',
        'environment',
        'aws_region',
        'instance_type',
        'key_pair_name',
        'allowed_ssh_cidr'
      ];
      
      requiredVariables.forEach(variable => {
        expect(variablesContent).toContain(`variable "${variable}"`);
      });
      
      console.log('All required Terraform variables are defined');
    });
  });

  describe('AWS Resource Validation', () => {
    test('should validate AWS region availability', async () => {
      console.log('Validating AWS region...');
      
      const regions = await ec2.describeRegions().promise();
      const availableRegions = regions.Regions.map(r => r.RegionName);
      
      expect(availableRegions).toContain(INFRA_CONFIG.region);
      
      console.log(`Region ${INFRA_CONFIG.region} is available`);
    });

    test('should validate availability zones in region', async () => {
      console.log('Validating availability zones...');
      
      const azs = await ec2.describeAvailabilityZones({
        Filters: [
          {
            Name: 'region-name',
            Values: [INFRA_CONFIG.region]
          },
          {
            Name: 'state',
            Values: ['available']
          }
        ]
      }).promise();
      
      expect(azs.AvailabilityZones.length).toBeGreaterThan(0);
      
      console.log(`Found ${azs.AvailabilityZones.length} availability zones in ${INFRA_CONFIG.region}`);
    });

    test('should validate AMI availability', async () => {
      console.log('Validating Ubuntu AMI availability...');
      
      const images = await ec2.describeImages({
        Owners: ['099720109477'], // Canonical
        Filters: [
          {
            Name: 'name',
            Values: ['ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*']
          },
          {
            Name: 'state',
            Values: ['available']
          }
        ]
      }).promise();
      
      expect(images.Images.length).toBeGreaterThan(0);
      
      // Find the most recent image
      const latestImage = images.Images.sort((a, b) => 
        new Date(b.CreationDate) - new Date(a.CreationDate)
      )[0];
      
      expect(latestImage).toBeTruthy();
      expect(latestImage.State).toBe('available');
      
      console.log(`Latest Ubuntu AMI: ${latestImage.ImageId} (${latestImage.CreationDate})`);
    });

    test('should validate instance type availability', async () => {
      console.log('Validating instance type availability...');
      
      const instanceTypes = await ec2.describeInstanceTypes({
        InstanceTypes: ['t3.micro', 't3.small', 't3.medium']
      }).promise();
      
      expect(instanceTypes.InstanceTypes.length).toBeGreaterThan(0);
      
      const availableTypes = instanceTypes.InstanceTypes.map(it => it.InstanceType);
      expect(availableTypes).toContain('t3.micro');
      
      console.log(`Available instance types: ${availableTypes.join(', ')}`);
    });
  });

  describe('Security Group Validation', () => {
    test('should validate security group rules configuration', () => {
      console.log('Validating security group configuration...');
      
      const terraformMainFile = path.join(__dirname, '../../terraform/main.tf');
      const mainContent = fs.readFileSync(terraformMainFile, 'utf8');
      
      // Check for required security group rules
      expect(mainContent).toContain('from_port   = 22'); // SSH
      expect(mainContent).toContain('from_port   = 80'); // HTTP
      expect(mainContent).toContain('from_port   = 443'); // HTTPS
      expect(mainContent).toContain('from_port   = 3000'); // Application
      
      // Check for egress rules
      expect(mainContent).toContain('egress');
      expect(mainContent).toContain('protocol    = "-1"'); // All protocols
      
      console.log('Security group configuration is valid');
    });

    test('should validate network ACL configuration', () => {
      console.log('Validating Network ACL configuration...');
      
      const terraformMainFile = path.join(__dirname, '../../terraform/main.tf');
      const mainContent = fs.readFileSync(terraformMainFile, 'utf8');
      
      // Check for Network ACL configuration
      expect(mainContent).toContain('aws_network_acl');
      expect(mainContent).toContain('rule_no');
      expect(mainContent).toContain('action     = "allow"');
      
      console.log('Network ACL configuration is valid');
    });
  });

  describe('Storage and Networking Validation', () => {
    test('should validate EBS volume configuration', () => {
      console.log('Validating EBS volume configuration...');
      
      const terraformMainFile = path.join(__dirname, '../../terraform/main.tf');
      const mainContent = fs.readFileSync(terraformMainFile, 'utf8');
      
      // Check for EBS volume configuration
      expect(mainContent).toContain('aws_ebs_volume');
      expect(mainContent).toContain('type              = "gp3"');
      expect(mainContent).toContain('encrypted         = true');
      
      // Check for volume attachment
      expect(mainContent).toContain('aws_volume_attachment');
      expect(mainContent).toContain('device_name');
      
      console.log('EBS volume configuration is valid');
    });

    test('should validate Elastic IP configuration', () => {
      console.log('Validating Elastic IP configuration...');
      
      const terraformMainFile = path.join(__dirname, '../../terraform/main.tf');
      const mainContent = fs.readFileSync(terraformMainFile, 'utf8');
      
      // Check for Elastic IP configuration
      expect(mainContent).toContain('aws_eip');
      expect(mainContent).toContain('domain   = "vpc"');
      
      console.log('Elastic IP configuration is valid');
    });

    test('should validate VPC and subnet configuration', () => {
      console.log('Validating VPC configuration...');
      
      const terraformMainFile = path.join(__dirname, '../../terraform/main.tf');
      const mainContent = fs.readFileSync(terraformMainFile, 'utf8');
      
      // Check for VPC data source
      expect(mainContent).toContain('data "aws_vpc" "default"');
      expect(mainContent).toContain('default = true');
      
      // Check for subnet data source
      expect(mainContent).toContain('data "aws_subnets" "default"');
      
      console.log('VPC configuration is valid');
    });
  });

  describe('IAM and CloudWatch Validation', () => {
    test('should validate IAM role configuration', () => {
      console.log('Validating IAM role configuration...');
      
      const terraformMainFile = path.join(__dirname, '../../terraform/main.tf');
      const mainContent = fs.readFileSync(terraformMainFile, 'utf8');
      
      // Check for IAM role
      expect(mainContent).toContain('aws_iam_role');
      expect(mainContent).toContain('AssumeRole');
      expect(mainContent).toContain('ec2.amazonaws.com');
      
      // Check for IAM policy
      expect(mainContent).toContain('aws_iam_role_policy');
      expect(mainContent).toContain('logs:CreateLogGroup');
      expect(mainContent).toContain('logs:PutLogEvents');
      
      // Check for instance profile
      expect(mainContent).toContain('aws_iam_instance_profile');
      
      console.log('IAM configuration is valid');
    });

    test('should validate CloudWatch log group configuration', () => {
      console.log('Validating CloudWatch configuration...');
      
      const terraformMainFile = path.join(__dirname, '../../terraform/main.tf');
      const mainContent = fs.readFileSync(terraformMainFile, 'utf8');
      
      // Check for CloudWatch log group
      expect(mainContent).toContain('aws_cloudwatch_log_group');
      expect(mainContent).toContain('retention_in_days');
      
      console.log('CloudWatch configuration is valid');
    });
  });

  describe('Terraform Outputs Validation', () => {
    test('should validate required outputs are defined', () => {
      console.log('Validating Terraform outputs...');
      
      const outputsFile = path.join(__dirname, '../../terraform/outputs.tf');
      
      if (fs.existsSync(outputsFile)) {
        const outputsContent = fs.readFileSync(outputsFile, 'utf8');
        
        // Check for essential outputs
        const requiredOutputs = [
          'server_public_ip',
          'server_private_ip',
          'security_group_id'
        ];
        
        requiredOutputs.forEach(output => {
          expect(outputsContent).toContain(`output "${output}"`);
        });
        
        console.log('All required outputs are defined');
      } else {
        console.log('No outputs.tf file found - creating basic validation');
        
        // Check main.tf for output definitions
        const mainFile = path.join(__dirname, '../../terraform/main.tf');
        const mainContent = fs.readFileSync(mainFile, 'utf8');
        
        // At minimum, we should be able to extract instance information
        expect(mainContent).toContain('aws_instance');
        expect(mainContent).toContain('aws_eip');
      }
    });
  });

  describe('Resource Tagging Validation', () => {
    test('should validate consistent resource tagging', () => {
      console.log('Validating resource tagging...');
      
      const terraformMainFile = path.join(__dirname, '../../terraform/main.tf');
      const mainContent = fs.readFileSync(terraformMainFile, 'utf8');
      
      // Check for default tags in provider
      expect(mainContent).toContain('default_tags');
      expect(mainContent).toContain('Project');
      expect(mainContent).toContain('Environment');
      expect(mainContent).toContain('ManagedBy');
      
      // Check for resource-specific tags
      expect(mainContent).toContain('tags = {');
      expect(mainContent).toContain('Name =');
      
      console.log('Resource tagging configuration is valid');
    });
  });

  describe('User Data Script Validation', () => {
    test('should validate user data script exists and is valid', () => {
      console.log('Validating user data script...');
      
      const userDataFile = path.join(__dirname, '../../terraform/user_data.sh');
      
      if (fs.existsSync(userDataFile)) {
        const userDataContent = fs.readFileSync(userDataFile, 'utf8');
        
        // Check for essential setup commands
        expect(userDataContent).toContain('#!/bin/bash');
        expect(userDataContent).toContain('apt-get update');
        
        console.log('User data script is valid');
      } else {
        console.log('No user_data.sh file found - checking inline user data');
        
        const terraformMainFile = path.join(__dirname, '../../terraform/main.tf');
        const mainContent = fs.readFileSync(terraformMainFile, 'utf8');
        
        // Check for user data configuration
        expect(mainContent).toContain('user_data');
      }
    });
  });
});

// Helper functions

async function verifyAWSCredentials() {
  console.log('Verifying AWS credentials...');
  
  try {
    const sts = new AWS.STS();
    const identity = await sts.getCallerIdentity().promise();
    
    expect(identity.Account).toBeTruthy();
    expect(identity.Arn).toBeTruthy();
    
    console.log(`AWS credentials verified for account: ${identity.Account}`);
    
  } catch (error) {
    throw new Error(`AWS credentials verification failed: ${error.message}`);
  }
}

async function validateResourceExists(resourceType, resourceId) {
  console.log(`Validating ${resourceType} exists: ${resourceId}`);
  
  try {
    switch (resourceType) {
      case 'instance':
        const instanceResult = await ec2.describeInstances({
          InstanceIds: [resourceId]
        }).promise();
        
        expect(instanceResult.Reservations.length).toBeGreaterThan(0);
        expect(instanceResult.Reservations[0].Instances.length).toBeGreaterThan(0);
        
        const instance = instanceResult.Reservations[0].Instances[0];
        expect(instance.State.Name).toBe('running');
        
        break;
        
      case 'security-group':
        const sgResult = await ec2.describeSecurityGroups({
          GroupIds: [resourceId]
        }).promise();
        
        expect(sgResult.SecurityGroups.length).toBe(1);
        
        break;
        
      case 'volume':
        const volumeResult = await ec2.describeVolumes({
          VolumeIds: [resourceId]
        }).promise();
        
        expect(volumeResult.Volumes.length).toBe(1);
        expect(volumeResult.Volumes[0].State).toBe('available');
        
        break;
        
      default:
        throw new Error(`Unknown resource type: ${resourceType}`);
    }
    
    console.log(`${resourceType} ${resourceId} validated successfully`);
    
  } catch (error) {
    throw new Error(`Resource validation failed: ${error.message}`);
  }
}

async function validateSecurityGroupRules(securityGroupId) {
  console.log(`Validating security group rules: ${securityGroupId}`);
  
  const sgResult = await ec2.describeSecurityGroups({
    GroupIds: [securityGroupId]
  }).promise();
  
  const securityGroup = sgResult.SecurityGroups[0];
  const ingressRules = securityGroup.IpPermissions;
  const egressRules = securityGroup.IpPermissionsEgress;
  
  // Check for required ingress rules
  const requiredPorts = [22, 80, 443, 3000];
  
  requiredPorts.forEach(port => {
    const ruleExists = ingressRules.some(rule => 
      rule.FromPort === port && rule.ToPort === port
    );
    expect(ruleExists).toBe(true);
  });
  
  // Check for egress rules (should allow all outbound)
  const allowAllEgress = egressRules.some(rule => 
    rule.IpProtocol === '-1' && 
    rule.IpRanges.some(range => range.CidrIp === '0.0.0.0/0')
  );
  
  expect(allowAllEgress).toBe(true);
  
  console.log('Security group rules validated successfully');
}