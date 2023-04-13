# Setting up AWS infrastructure using Terraform

## :package: Prerequisites

Install:

- `aws-cli` [[link](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)]
- `terraform` [[link](https://developer.hashicorp.com/terraform/downloads)]

## :arrow_heading_down: Installation

Prerequisite: ssh configured on your local system to clone this project using ssh.

> Clone the server side API service using the following command:

shell
git@github.com:Cloudworkspring23/awsinfra.git


> To clone the forked repository, use the following command:

shell
git@github.com:bhatiaarjun19/awsinfrafork.git


> Configure the aws-cli [[link](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html)]

## :pager: AWS Command Line Interface (v2)

- Install and configure AWS Command Line Interface (CLI) on your development machine (laptop). See [Install the AWS Command Line Interface](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) for detailed instructions to use AWS CLI with Windows, MacOS or Linux.
- Below are the steps to download and use the AWS CLI on MacOS:
- Download the file using the `curl` command:

```shell
# On macOS only
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
```

- Run the `macOS installer` to install AWS CLI:

```shell
# On macOS only
sudo installer -pkg ./AWSCLIV2.pkg -target /
```

- Verify that `zsh` can find and run `aws` command using the following commands:

```shell
which aws
#/usr/local/bin/aws
aws --version
#aws-cli/2.8.2 Python/3.9.11 Darwin/21.6.0 exe/x86_64 prompt/off
```

> NOTE: Alternatively, you can use the homebrew to install AWS CLI v2 on your Mac. See detailed instructions [here](https://formulae.brew.sh/formula/awscli).

- Create a `CLI` group in your `dev` and `prod` root accounts, on the AWS Console.
- Provide the `Administrator Access` policy to this group.
- Add the `dev-cli` and `prod-cli` users to their respective user groups.
- In the terminal, create `dev` user profile for your dev AWS account and `prod` user profile for your production AWS account. **Do not set up a `default` profile**.
- Both `dev` and `prod` AWS CLI profiles should be set to use the `us-east-1` region or the region closest to you.
- To create a profile, use the set of following command:

```shell
aws configure --profile <profile-name>
```

- The above command will ask you to fill out the following:
  - `AWS Access Key ID`
  - `AWS Secret Access Key`
  - `Region`
  - `Output`

- To change the region on any profile, use the following command:

```shell
# change the region
aws configure set region <region-name> --profile dev
```

```shell
# you can omit --profile dev is you have env variables set (see below)
aws configure set region <region-name>
```

- To use a particular profile, use the command:

```shell
# For prod profile
export AWS_PROFILE=prod
```

```shell
# For dev profile
export AWS_PROFILE=dev
```

- To stop using a profile, use the following command:

```shell
# To stop using a profile
export AWS_PROFILE=
```
## :rocket: AWS infrastructure setup

>Initialize Terraform

shell
  terraform init


> To create an execution plan with default configurations and to apply it

shell
  terraform plan
  terraform apply


> To destroy all managed objects created by the plan
> 
shell
  terraform destroy

## :desktop_computer: AWS AMI (Amazon Machine Images)

### [Default VPC](https://docs.aws.amazon.com/vpc/latest/userguide/default-vpc.html#create-default-vpc)

To create a default VPC in case you deleted the default VPC in your AWS account, use the following command:

```shell
aws ec2 create-default-vpc
```

### Custom AMI

To create a stack with custom AMI, replace the AMI default value under the `AMI` parameter with the custom AMI id that is created using [Packer](https://www.packer.io
):

```yaml
parameters:
  AMI:
    Type: String
    Default: "<your-ami-id>"
    Description: "The custom AMI built using Packer"
```

> NOTE: For more details on how we'll be using HCP Packer, refer [here](https://github.com/VoskhodXIV/webservice#package-packer).

### :hammer: Configuration

To launch the EC2 AMI at CloudFormation stack creation, we need to have a few configurations in place.

#### Custom security group

We need to create a custom security group for our application with the following `ingress rules` to allow TCP traffic on our `VPC`:

- `SSH` protocol on PORT `22`.
- `HTTP` protocol on PORT `80`.
- `HTTPS` protocol on PORT `443`.
- PORT `5000` for our webapp to be hosted on. (This can vary according to developer needs)
- Their IPs should be accessible from anywhere in the world.

#### AWS EC2 AMI instance

To launch the custom EC2 AMI using the CloudFormation stack, we need to configure the EC2 instance with the custom security group we created above, and then define the `EBS volumes` with the following properties:

- Custom AMI ID (created using Packer)
- Instance type : `t2.micro`
- Protected against accidental termination: `no`
- Root volume size: 50
- Root volume type: `General Purpose SDD (GP2)`

#### AWS S3 and RDS configuration

To use the RDS and S3 on AWS we need to configure the following:

- `AWS::S3::Bucket`
  - Default encryption for bucket.
  - Lifecycle policy to change storage type from `STANDARD` to `STANDARD_IA` after 30 days.
- `AWS::RDS::DBParameterGroup`
  - DB Engine config.
- `AWS::RDS::DBSubnetGroup`
- `AWS::EC2::SecurityGroup`
  - Ingress rule for `5000` port for MySQL.
  - `Application Security Group` is the source for traffic.
- `AWS::IAM::Role`
- `AWS::IAM::InstanceProfile`
- `AWS::IAM::Policy`

  ```json
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:*"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::YOUR_BUCKET_NAME",
                "arn:aws:s3:::YOUR_BUCKET_NAME/*"
            ]
        }
    ]
  }
  ```

  > NOTE: Replace `*` with appropriate permissions for the S3 bucket to create security policies.
- `AWS::RDS::DBInstance`
  - Configure the following:
    - Database Engine:  MySQL/PostgreSQL
    - DB Instance Class:  db.t3.micro
    - Multi-AZ deployment:  No
    - DB instance identifier: csye6225
    - Master username: csye6225
    - Master password: pick a strong password
    - Subnet group: Private subnet for RDS instances
    - Public accessibility: No
    - Database name: csye6225

> NOTE: To run the application on a custom bucket, we need to update the `UserData` field in the `AWS::EC2::Instance`.

- To hard delete a bucket, you can use the following command:

```shell
aws s3 rm s3://<bucket-name> --recursive
```

#### DNS configuration using AWS Route53

To configure the Domain Name System (DNS), we need to do the following **from the AWS Console**:

1. Register a domain with a domain registrar [(Namecheap)](https://www.namecheap.com/domains/registration.aspx). Namecheap offers free domain for a year with Github Student Developer pack.
2. Configure AWS Route53 for DNS service:
   1. Create a `HostedZone` for the **root** AWS account, where we create a public hosted zone for domain `yourdomainname.tld`.
   2. Configure Namecheap with the custom `Name Servers` provided by AWS Route53 to use Route53 name servers.
   3. Create a public hosted zone in the **dev** AWS account, with the subdomain `dev.yourdomainname.tld`.
   4. Create a public hosted zone in the **prod** AWS account, with the subdomain `prod.yourdomainname.tld`.
   5. Configure the name servers and subdomain in the root AWS account (for both dev and prod).
3. AWS Route53 is updated from the CloudFormation template. We need to add an `A` record to the Route53 zone so that your domain points to your EC2 instance and your web application is accessible through `http://your-domain-name.tld/`.
4. The application must be accessible using root context i.e. `http://your-domain-name.tld/` and not `http://your-domain-name.tld/app-0.1/`.


## :closed_lock_with_key: SSL Certificate

To get a SSL Certificate for your domain, visit [ZeroSSL](https://app.zerossl.com/dashboard). Follow the instructions to setup SSL for Amazon Web Services.

You may need to add the `CNAME` record to `Amazon Route 53` to get the SSL working.

To import the SSL certificate and private keys that you download from `ZeroSSL`, use the following command:

```shell
aws acm import-certificate --certificate fileb://certificate.crt --certificate-chain fileb://ca_bundle.crt --private-key fileb://private.key
```