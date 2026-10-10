"""Publish simulated pond feeding-sensor telemetry to AWS IoT Core (topic vn/aquaculture-feed/telemetry).

The IoT rule lands each message in S3; Snowpipe loads it into RAW.LIVE_TELEMETRY.
Pond IDs come from RAW.PONDS (PND-0000..PND-0029). Values are seeded random.
"""
import argparse
import json
import random
from datetime import datetime, timezone

TOPIC = 'vn/aquaculture-feed/telemetry'


def build_message(rng, now=None):
    """One synthetic reading: uneaten feed (kg) and auto-feeder hopper level (%)."""
    now = now or datetime.now(timezone.utc)
    alarm = rng.random() < 0.1
    return {'pond_id': f'PND-{rng.randint(0, 29):04d}',
            'event_ts': now.strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
            'uneaten_feed_kg': round(rng.gauss(95.0 if alarm else 25.0, 6.0), 1),
            'hopper_level_pct': round(min(100.0, rng.gauss(94 if alarm else 70, 3)), 1),
            'status': 'ALARM' if alarm else 'NORMAL'}


def publish_request(message):
    """Keyword arguments for the iot-data Publish call."""
    return {'topic': TOPIC, 'qos': 1, 'payload': json.dumps(message).encode('utf-8')}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--region', default='us-west-2')
    ap.add_argument('--count', type=int, default=40)
    ap.add_argument('--seed', type=int)
    args = ap.parse_args()
    import boto3
    iot = boto3.client('iot', region_name=args.region)
    endpoint = iot.describe_endpoint(endpointType='iot:Data-ATS')['endpointAddress']
    data = boto3.client('iot-data', region_name=args.region, endpoint_url=f'https://{endpoint}')
    rng = random.Random(args.seed)
    for _ in range(args.count):
        data.publish(**publish_request(build_message(rng)))
    print(f'published {args.count} messages to {TOPIC} via {endpoint}')


if __name__ == '__main__':
    main()
