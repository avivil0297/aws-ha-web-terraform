#!/usr/bin/env bash
# Live scaling demo: load the web servers and watch the ASG react.
#   ./scripts/stress-demo.sh start [duration]   CPU load on every running web server (default 15m)
#   ./scripts/stress-demo.sh watch              live view: desired, instances, alarms, CPU (Ctrl+C to exit)
#   ./scripts/stress-demo.sh status             one snapshot of the above
#   ./scripts/stress-demo.sh stop               stop the load now
set -euo pipefail
cd "$(dirname "$0")/.."

REGION="${AWS_REGION:-us-east-1}"
ASG="final-lab-web-asg"
ALARM_PREFIX="TargetTracking-${ASG}"

web_ips() {
  aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].PrivateIpAddress' --output text
}

on_web() {  # run a command on one web server through the bastion
  ssh -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR \
    -J "ubuntu@$BASTION" "ubuntu@$1" "$2"
}

status() {
  local desired instances high low cpu
  desired=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" --auto-scaling-group-names "$ASG" \
    --query 'AutoScalingGroups[0].DesiredCapacity' --output text)
  instances=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" --auto-scaling-group-names "$ASG" \
    --query 'AutoScalingGroups[0].Instances[].[AvailabilityZone,LifecycleState]' --output text | sort | uniq -c | awk '{printf "%s×%s/%s  ", $1, $2, $3}')
  high=$(aws cloudwatch describe-alarms --region "$REGION" --alarm-name-prefix "${ALARM_PREFIX}-AlarmHigh" \
    --query 'MetricAlarms[0].StateValue' --output text)
  low=$(aws cloudwatch describe-alarms --region "$REGION" --alarm-name-prefix "${ALARM_PREFIX}-AlarmLow" \
    --query 'MetricAlarms[0].StateValue' --output text)
  cpu=$(aws cloudwatch get-metric-statistics --region "$REGION" --namespace AWS/EC2 --metric-name CPUUtilization \
    --dimensions "Name=AutoScalingGroupName,Value=$ASG" --statistics Average --period 300 \
    --start-time "$(date -u -d '-15 min' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" \
    --query 'sort_by(Datapoints,&Timestamp)[-1].Average' --output text)
  [ "$cpu" = "None" ] && cpu="-" || cpu=$(printf '%.0f%%' "$cpu")
  printf '%s  desired=%s  CPU(avg)=%-5s  AlarmHigh=%-6s AlarmLow=%-6s  %s\n' \
    "$(date +%H:%M:%S)" "$desired" "$cpu" "$high" "$low" "$instances"
}

case "${1:-}" in
  start)
    DURATION="${2:-15m}"
    BASTION=$(terraform output -raw bastion_public_ip)
    for ip in $(web_ips); do
      echo "Starting stress-ng on $ip for $DURATION ..."
      on_web "$ip" "sudo apt-get install -y -qq stress-ng >/dev/null 2>&1
        sudo systemctl stop stress 2>/dev/null || true
        sudo systemd-run --quiet --unit=stress stress-ng --cpu 0 --timeout $DURATION && echo '  running'"
    done
    echo "Scale-out expected in about 5 minutes. Follow it with: $0 watch"
    ;;
  stop)
    BASTION=$(terraform output -raw bastion_public_ip)
    for ip in $(web_ips); do
      on_web "$ip" "sudo systemctl stop stress 2>/dev/null || true" && echo "Stopped on $ip"
    done
    ;;
  status)
    status
    ;;
  watch)
    echo "Refreshing every 15s. Ctrl+C to exit."
    while true; do status; sleep 15; done
    ;;
  *)
    sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
