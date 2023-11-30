import {
  AutoScalingClient,
  DescribeAutoScalingGroupsCommand,
  SetDesiredCapacityCommand,
} from '@aws-sdk/client-auto-scaling'
import { DescribeInstancesCommand, EC2Client } from '@aws-sdk/client-ec2'
import {
  ChangeResourceRecordSetsCommand,
  Route53Client,
} from '@aws-sdk/client-route-53'
import { APIGatewayProxyEventV2, Handler } from 'aws-lambda'
import nacl from 'tweetnacl'

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

const region = process.env.AWS_REGION
const autoscalingClient = new AutoScalingClient({ region })
const ec2Client = new EC2Client({ region })
const route53Client = new Route53Client({ region })

async function scaleServer(): Promise<string> {
  const describeGroupsCommand = new DescribeAutoScalingGroupsCommand({})
  const autoscalingGroupsResponse = await autoscalingClient.send(
    describeGroupsCommand
  )

  if (!autoscalingGroupsResponse.AutoScalingGroups?.length) {
    throw new Error('No Auto Scaling groups found in the account.')
  }

  const firstGroup =
    autoscalingGroupsResponse.AutoScalingGroups[0].AutoScalingGroupName

  if (!firstGroup) {
    throw new Error('No Auto Scaling groups found in the account.')
  }

  const setDesiredCapacityCommand = new SetDesiredCapacityCommand({
    AutoScalingGroupName: firstGroup,
    DesiredCapacity: 1,
    HonorCooldown: false,
  })
  await autoscalingClient.send(setDesiredCapacityCommand)
  return firstGroup
}

async function getIPAddressOfInstance(group: string) {
  let updatedGroup
  do {
    updatedGroup = await autoscalingClient.send(
      new DescribeAutoScalingGroupsCommand({
        AutoScalingGroupNames: [group],
      })
    )
    if ((updatedGroup.AutoScalingGroups?.[0]?.Instances?.length || 0) < 1) {
      console.log(
        'Waiting for instance to spin up...',
        updatedGroup.AutoScalingGroups
      )
      await sleep(5000)
    }
  } while ((updatedGroup.AutoScalingGroups?.[0]?.Instances?.length || 0) < 1)

  const instanceId =
    updatedGroup.AutoScalingGroups?.[0].Instances?.[0].InstanceId
  if (!instanceId) {
    throw new Error('No EC2 instances found in the Auto Scaling group.')
  }

  const instanceDescription = await ec2Client.send(
    new DescribeInstancesCommand({ InstanceIds: [instanceId] })
  )
  const instance = instanceDescription.Reservations?.[0].Instances?.[0]
  const instanceIp = instance?.PublicIpAddress
  if (!instanceIp) {
    throw new Error('The EC2 instance does not have a public IP address.')
  }
  return instanceIp
}

async function updateRoute53(ip: string) {
  const hostedZoneId = 'Z04844402254N20RKHUEK'
  const recordSetName = 'ethanmick.xyz'
  const changeResourceRecordSetsCommand = new ChangeResourceRecordSetsCommand({
    HostedZoneId: hostedZoneId,
    ChangeBatch: {
      Changes: [
        {
          Action: 'UPSERT',
          ResourceRecordSet: {
            Name: recordSetName,
            Type: 'A',
            TTL: 60,
            ResourceRecords: [{ Value: ip }],
          },
        },
      ],
    },
  })
  return route53Client.send(changeResourceRecordSetsCommand)
}

async function main() {
  try {
    const group = await scaleServer()
    const ip = await getIPAddressOfInstance(group)
    await updateRoute53(ip)
  } catch (error) {
    console.error('Error', error)
  }
}

async function verify(event: APIGatewayProxyEventV2) {
  const PUBLIC_KEY =
    '5868eb7b0998d99b2b58db818d17f819ff7362476ef337c49e33342909c2ab72'

  const signature = event.headers['x-signature-ed25519'] || ''
  const timestamp = event.headers['x-signature-timestamp'] || ''
  const body = event.body || ''

  try {
    return nacl.sign.detached.verify(
      Buffer.from(timestamp + body),
      Buffer.from(signature, 'hex'),
      Buffer.from(PUBLIC_KEY, 'hex')
    )
  } catch {
    return false
  }
}

export const handler: Handler<APIGatewayProxyEventV2> = async (
  event,
  context
) => {
  if (!(await verify(event))) {
    return {
      isBase64Encoded: false,
      statusCode: 401,
      headers: { 'Content-Type': 'application/json' },
      multiValueHeaders: {},
      body: '',
    }
  }

  const body = JSON.parse(event.body || '{}')
  if (body.type == 1) {
    return {
      isBase64Encoded: false,
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      multiValueHeaders: {},
      body: JSON.stringify({ type: 1 }),
    }
  }

  try {
    await main()
  } catch (err: any) {
    console.error('Error spinning up server', err)
  }

  return {
    isBase64Encoded: false,
    statusCode: 202,
    headers: { 'Content-Type': 'application/json' },
    multiValueHeaders: {},
    body: JSON.stringify({ type: 4, data: { content: 'Server Started.' } }),
  }
}
