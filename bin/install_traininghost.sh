#Checking whether the user is added in the docker group or not.
if [[ $(groups | grep docker) ]]; then
        echo "You are already added to the docker group!"
else
    sudo groupadd docker	
    sudo usermod -aG docker $USER
    echo "Adding you to the docker group re-login is required."
    echo "Exiting now try to login again."
    exit
fi

tools/kubernetes/install_k8s.sh
tools/nfs/configure_nfs_server.sh localhost
tools/helm/install_helm.sh
tools/nfs/install_nfs_subdir_external_provisioner.sh localhost

sudo bin/install_common_templates_to_helm.sh
tools/leofs/bin/install_leofs.sh
tools/kubeflow/bin/install_kubeflow.sh
kubectl create namespace traininghost

bin/install_rolebindings.sh
bin/install_databases.sh
bin/install.sh -f RECIPE_EXAMPLE/example_recipe_oran_g_release.yaml
