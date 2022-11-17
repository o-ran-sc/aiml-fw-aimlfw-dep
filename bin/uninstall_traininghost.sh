bin/uninstall.sh
bin/uninstall_databases.sh
helm repo remove local
sudo helm plugin uninstall servecm


tools/kubeflow/bin/uninstall_kubeflow.sh
tools/leofs/bin/uninstall_leofs.sh
bin/uninstall_rolebindings.sh
kubectl delete namespace traininghost

tools/nfs/delete_nfs_subdir_external_provisioner.sh
tools/kubernetes/uninstall_k8s.sh