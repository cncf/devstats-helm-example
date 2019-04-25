# AWS Ingress setup

Remember to set `AWS_PROFILE` and `KUBECONFIG`.

- First you need `ngingx-ingress`: `helm install stable/nginx-ingress --name nginx-ingress`.
- Note External-IP field from `kubectl --namespace devstats get services -o wide -w nginx-ingress-controller` when ready.
- Register a domain in AWS via: `aws route53domains register-domain --generate-cli-skeleton > in.json`. Fill that JSON `vim in.json`.
- Register domain via: `cat in.json | jq -cM . | AWS_PROFILE=... xargs -d '\n' aws route53domains register-domain --cli-input-json`
- Create AWS hosted zone: `aws route53 create-hosted-zone --name "devstats.demo.io" --caller-reference "devstats.demo.io-$(date +%s)"`. Note its ID.
- Use `aws route53 list-hosted-zones` to list hosted zones.
- Use `aws route53 list-resource-record-sets --hosted-zone-id "/hostedzone/xxx"` to list hosted zone records.
- To add mapping to our `ingress-nginx`: `aws route53 change-resource-record-sets --hosted-zone-id xxx --change-batch '{"Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"*","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"xxx.us-east-1.elb.amazonaws.com"}]}}]}'`.
- To add mapping for the domain itself (not subdomains): `aws route53 change-resource-record-sets --hosted-zone-id xxx --change-batch '{"Changes":[{"Action":"CREATE","ResourceRecordSet":{"Name":"devstats.demo.io.","Type":"A","AliasTarget":{"HostedZoneId":"xxx","DNSName":"dualstack.xxx.us-east-1.elb.amazonaws.com.","EvaluateTargetHealth":false}}}]}'`
- To list DNS servers assigned to this new hosted zone: `aws route53 list-resource-record-sets --output json --hosted-zone-id "/hostedzone/xxx" --query "ResourceRecordSets[?Type == 'NS']" | jq -r '.[0].ResourceRecords[].Value'`.
- To check if DNS is working: `dig +short @first-dns-server. cncf.devstats.demo.io`. you can use `anything.devstats.demo.io` because this is a wildcard domain.
- To delete mapping to our `ingress-nginx`: `aws route53 change-resource-record-sets --hosted-zone-id xxx --change-batch '{"Changes": [{"Action": "DELETE","ResourceRecordSet": {"Name": "*","Type": "CNAME","TTL": 300,"ResourceRecords": [{ "Value": "xxx.us-east-1.elb.amazonaws.com"}]}}]}'`.
- You can delete histed zone via `AWS_PROFILE=cncf aws route53 delete-hosted-zone --id "/hostedzone/xxx"`.
