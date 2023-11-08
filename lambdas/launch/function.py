import boto3
import time
import os
from botocore.exceptions import NoCredentialsError, PartialCredentialsError

# Define a Python function that performs the tasks outlined
def update_autoscaling_and_route53():
    try:
        # Create an Auto Scaling client
        autoscaling_client = boto3.client('autoscaling')

        # Fetch the first Auto Scaling group
        autoscaling_groups = autoscaling_client.describe_auto_scaling_groups()
        if not autoscaling_groups['AutoScalingGroups']:
            return "No Auto Scaling groups found in the account."

        first_group = autoscaling_groups['AutoScalingGroups'][0]['AutoScalingGroupName']

        # Set the desired capacity of the first Auto Scaling group to 1
        autoscaling_client.set_desired_capacity(AutoScalingGroupName=first_group, DesiredCapacity=1, HonorCooldown=False)

        # Wait for the instance to be created and in service
        updated_group = autoscaling_client.describe_auto_scaling_groups(AutoScalingGroupNames=[first_group])
        while len(updated_group['AutoScalingGroups'][0]['Instances']) < 1:
            updated_group = autoscaling_client.describe_auto_scaling_groups(AutoScalingGroupNames=[first_group])
            # Sleep for 5 seconds
            time.sleep(5)

        # Fetch the first EC2 instance in that Auto Scaling group
        instances = updated_group['AutoScalingGroups'][0]['Instances']
        if not instances:
            return "No EC2 instances found in the Auto Scaling group."
        
        first_instance_id = instances[0]['InstanceId']

        # Create an EC2 client to get the public IP of the instance
        ec2_client = boto3.client('ec2')
        instance_description = ec2_client.describe_instances(InstanceIds=[first_instance_id])
        instance = instance_description['Reservations'][0]['Instances'][0]
        instance_ip = instance['PublicIpAddress']

        # Create a Route53 client
        route53_client = boto3.client('route53')

        # Assume we have the hosted zone ID and the record set name
        hosted_zone_id = 'Z04844402254N20RKHUEK'
        record_set_name = 'ethanmick.xyz'

        # Update the Route53 A record to point to the EC2 instance
        response = route53_client.change_resource_record_sets(
            HostedZoneId=hosted_zone_id,
            ChangeBatch={
                'Changes': [{
                    'Action': 'UPSERT',
                    'ResourceRecordSet': {
                        'Name': record_set_name,
                        'Type': 'A',
                        'TTL': 300,
                        'ResourceRecords': [{'Value': instance_ip}]
                    }
                }]
            }
        )
        return "Route53 A record updated successfully."

    except NoCredentialsError:
        return "No AWS credentials found."
    except PartialCredentialsError:
        return "AWS credentials are incomplete."
    except Exception as e:
        return f"An error occurred: {e}"


secret = os.environ['AUTHORIZATION_SECRET']

def handler(event, context):
    auth = event['Authorization']
    if not auth or auth != secret:
        return {
            'statusCode': 403,
            'body': 'Unauthorized'
        }
    result = update_autoscaling_and_route53()
    return {
        'statusCode': 202,
    }