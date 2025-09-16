# Pasos para destruir rancher

0) Variables y kubeconfig
export AWS_PROFILE=eks-operator
export AWS_REGION=us-east-1
export CLUSTER_NAME=my-eks-cluster

aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION" --alias "$CLUSTER_NAME"
kubectl config use-context "$CLUSTER_NAME"

1) Limpiar Rancher y add-ons (Kubernetes)
1.1 Desinstalar charts
helm -n cattle-system  uninstall rancher        || true
helm -n cert-manager   uninstall cert-manager   || true
helm -n ingress-nginx  uninstall ingress-nginx  || true

1.2 Borrar namespaces de Rancher/Fleet/Cert-Manager/Ingress
kubectl delete ns \
  cattle-system cattle-fleet-system cattle-fleet-clusters-system \
  cattle-global-data cattle-impersonation-system \
  cert-manager ingress-nginx --ignore-not-found=true

1.3 Borrar CRDs (cert-manager y rancher/fleet)
# cert-manager
kubectl get crds -o name | grep -E 'cert-manager\.io' | xargs -r kubectl delete

# rancher/fleet (todas las *.cattle.io)
kubectl get crds -o name | grep -E '\.cattle\.io$' | xargs -r kubectl delete

1.4 Webhooks, APIService, IngressClass y Services tipo LB
# APIService de Rancher
kubectl get apiservice -o name | grep -i cattle | xargs -r kubectl delete

# Webhooks
kubectl get validatingwebhookconfigurations -o name | grep -Ei 'rancher|cattle|ingress-nginx|cert-manager' | xargs -r kubectl delete
kubectl get mutatingwebhookconfigurations   -o name | grep -Ei 'rancher|cattle|ingress-nginx|cert-manager' | xargs -r kubectl delete

# IngressClass
kubectl get ingressclass -o name | grep -Ei 'nginx' | xargs -r kubectl delete

# Services tipo LoadBalancer residuales (por si quedó alguno)
kubectl get svc -A | awk '$5=="LoadBalancer"{print $1,$2}' | \
while read ns name; do kubectl -n "$ns" delete svc "$name"; done

1.5 Verificación rápida (debe imprimir “OK …” y/o “No resources found”)
kubectl get ns cattle-system cert-manager ingress-nginx || true
kubectl get crds | grep -E 'cattle\.io|management\.cattle\.io|fleet\.cattle\.io|project\.cattle\.io' || echo "OK: sin CRDs de Rancher"
kubectl get crds | grep -E 'cert-manager\.io' || echo "OK: sin CRDs de cert-manager"
kubectl get apiservice | grep -i cattle || echo "OK: sin APIService de Rancher"
kubectl get validatingwebhookconfigurations | grep -Ei 'rancher|cattle|ingress-nginx|cert-manager' || echo "OK: sin VWH"
kubectl get mutatingwebhookconfigurations   | grep -Ei 'rancher|cattle|ingress-nginx|cert-manager' || echo "OK: sin MWH"
kubectl get ingressclass || echo "OK: sin IngressClass"
kubectl get svc -A | grep LoadBalancer || echo "OK: sin Services tipo LB"

2) Destruir “addons” con Terraform (ingress-nginx, cert-manager, rancher)

Desde tu carpeta addons/:

2.1 Camino feliz
cd addons
terraform init -upgrade
terraform destroy -auto-approve

2.2 Plan B (si aparece “Provider configuration not present” o estado roto)
# quita del estado lo que ya borraste a mano
terraform state list | egrep 'helm_release|kubernetes_namespace' || true
# si lista algo, bórralo del estado:
terraform state rm $(terraform state list | egrep 'helm_release|kubernetes_namespace') || true

# reintenta destroy
terraform destroy -auto-approve

3) Destruir la infra base (EKS, node groups, VPC, etc.)

Ve al root donde declaras el module "eks" { ... } (tu proyecto base; p. ej. cross-account-architecture/ o donde lo tengas):

cd /ruta/a/tu/proyecto/base
terraform init -upgrade
terraform destroy -auto-approve


Si Terraform se queja porque aún existe algún Load Balancer o ENI, vuelve a correr el bloque 1.4 y verifica que no quede ningún Service tipo LoadBalancer en el clúster (o que el clúster ya esté borrado).

4) Limpieza local (opcional)
# elimina el contexto de kubeconfig
kubectl config delete-context "$CLUSTER_NAME" || true
kubectl config get-contexts

# variables
unset AWS_PROFILE AWS_REGION CLUSTER_NAME


# en caso de quedar residuales

1) Quitar APIService residuales
kubectl delete apiservice \
  v1.provisioning.cattle.io \
  v1alpha1.fleet.cattle.io \
  v3.management.cattle.io \
  --ignore-not-found

2) Borrar CRDs que quedan (y sus finalizers)
for crd in $(kubectl get crd -o name | grep -E 'cattle\.io|fleet\.cattle\.io|management\.cattle\.io|project\.cattle\.io'); do
  kubectl patch $crd -p '{"metadata":{"finalizers":[]}}' --type=merge || true
  kubectl delete $crd --ignore-not-found=true
done

3) Forzar cierre de namespaces “Terminating”

Requiere jq. (Si no lo tienes, te paso alternativa abajo).

for ns in cattle-system cert-manager ingress-nginx \
          cattle-fleet-system cattle-fleet-clusters-system \
          cattle-global-data cattle-impersonation-system; do
  kubectl get ns $ns >/dev/null 2>&1 || continue
  kubectl get ns $ns -o json | jq '.spec.finalizers=null' \
  | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - || true
done


Sin jq (alternativa):

for ns in cattle-system cert-manager ingress-nginx \
          cattle-fleet-system cattle-fleet-clusters-system \
          cattle-global-data cattle-impersonation-system; do
  kubectl patch ns $ns -p '{"spec":{"finalizers":[]}}' --type=merge || true
done

4) Verificación rápida
kubectl get ns cattle-system cert-manager ingress-nginx || true
kubectl get crds | grep -E 'cattle\.io|management\.cattle\.io|fleet\.cattle\.io|project\.cattle\.io' || echo "OK: sin CRDs Rancher/Fleet"
kubectl get apiservice | grep -i cattle || echo "OK: sin APIService de Rancher/Fleet"
kubectl get svc -A | grep LoadBalancer || echo "OK: sin Services tipo LB"

5) Terraform “addons/”

Desde tu carpeta addons/:

cd addons
terraform state list | egrep 'helm_release|kubernetes_namespace' && \
  terraform state rm $(terraform state list | egrep 'helm_release|kubernetes_namespace') || true

terraform destroy -auto-approve
