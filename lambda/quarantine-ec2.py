import json,boto3
import datetime
import time

def lambda_handler(event, context):
    print(event)
    
    ec2_client = boto3.client('ec2')
    ssm_client = boto3.client('ssm')
    ir_client = boto3.client('ssm-incidents')
    
    instance_id=event
    print("EC2 Instance:",instance_id)
    
    #0. Create Incident
    print("Creating Incident...")
    response = ir_client.start_incident(
      title=f'Compromised EC2 - {instance_id}',
      responsePlanArn='arn:aws:ssm-incidents::767880573454:response-plan/Compromised-EC2'
    )
    
    #1. remove all security groups, attach quarantine security group
    response = ec2_client.create_tags(
      Resources=[instance_id],
      Tags=[
        {
            'Key': 'QUARANTINE',
            'Value': 'Initiated - Step 1'
        },
      ]
    )
    
    response = ec2_client.modify_instance_attribute(
      #Attribute='groupSet',
      Groups=["sg-0baafe3b702f71904"],
      InstanceId=instance_id
    )

    #2. run forensic collection script
    print("Running forensic collection...")
    response = ec2_client.create_tags(
      Resources=[instance_id],
      Tags=[
        {
            'Key': 'QUARANTINE',
            'Value': 'Initiated - Step 2'
        },
      ]
    )
    
    try:
      response = ssm_client.send_command(
        InstanceIds=[instance_id],
        DocumentName='AWS-RunShellScript',
        Parameters={
          'commands': ['/root/sysops/proc-livecapture.sh']
        }
      )
    except Exception as e:
      print("Could not run Capture Procs Script:",e)
    
    # wait 120 seconds for script to complete (increase if doing memory dump)
    print("Sleeping 120 seconds...")
    time.sleep(90)

    #3. power down ec2 instance
    print("Stopping Instance...")
    response = ec2_client.create_tags(
      Resources=[instance_id],
      Tags=[
        {
            'Key': 'QUARANTINE',
            'Value': 'Initiated - Step 3'
        },
      ]
    )
    
    response=ec2_client.stop_instances(
      InstanceIds=[instance_id]
    )

    #4. create snapshot (image)
    print("Creating Image...")
    response = ec2_client.create_tags(
      Resources=[instance_id],
      Tags=[
        {
            'Key': 'QUARANTINE',
            'Value': 'Initiated - Step 4'
        },
      ]
    )
    
    #wait up to 3 minutes while instance turns off, before making AMI

    print("begin waiter")
    waiter=ec2_client.get_waiter('instance_stopped')
    waiter.wait(
      InstanceIds=[instance_id],
      WaiterConfig={
        'Delay':30,
        'MaxAttempts':6
      }
    )
    print("end waiter")

    today=datetime.date.today()
    time_now=time.strftime("%H:%M:%S%z")
    
    #Get current ec2 tags
    response = ec2_client.describe_tags(
      Filters=[
        {
            'Name': 'resource-id',
            'Values': ['i-03d233edf1ac19936']
        },
      ]
    )
    
    tags=response['Tags']

    new_tags=[]
    
    for tag in tags:
      new_tags.append({'Key': tag['Key'], 'Value': tag['Value']})

    new_tag={'Key': 'Quarantine-Date', 'Value': f'{today} {time_now}'}

    new_tags.append(new_tag)

    response=ec2_client.create_image(
      Description=f'{instance_id} QUARANTINED Instance',
      InstanceId=instance_id,
      Name=f'{instance_id}-QUARANTINED-Instance-{today}',
      TagSpecifications=[
        {
            'ResourceType': 'image',
            'Tags': new_tags
        }
      ]
    )
    
    response = ec2_client.create_tags(
      Resources=[instance_id],
      Tags=[
        {
            'Key': 'QUARANTINE',
            'Value': 'Completed'
        },
      ]
    )
    
    msg="EC2 Quarantine Completed - "+instance_id
    return msg

