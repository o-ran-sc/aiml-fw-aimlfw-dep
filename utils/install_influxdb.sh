#!/bin/bash

# Script to:
# 1. Ensure pip3 and python3-venv are installed.
# 2. Create a Python virtual environment.
# 3. Install Python dependencies (pandas, influxdb_client) into the virtual environment.
# 4. Clone a Git repository.
# 5. Change into the cloned repository's subdirectory.
# 6. Install a Helm release for InfluxDB.
# 7. Wait for its pod to be ready.
# 8. Fetch and decode the admin user token.
# 9. Create an InfluxDB bucket named 'UEData'.

# --- Configuration ---
HELM_RELEASE_NAME="my-release"
CHART_NAME="bitnami/influxdb"
CHART_VERSION="5.13.5"
IMAGE_REPOSITORY="bitnamilegacy/influxdb"
SECRET_NAME="${HELM_RELEASE_NAME}-influxdb"
TOKEN_KEY="admin-user-token"
BUCKET_NAME="UEData"
ORG_NAME="primary"
WAIT_TIMEOUT="300s"
PYTHON_PACKAGES="pandas influxdb_client"
VENV_DIR="venv" # Name for the virtual environment directory
# --- End of Configuration ---
# --- Function to check and install pip3 and python3-venv ---
install_prerequisites_if_needed() {
  echo "Checking for pip3..."
  if ! command -v pip3 &> /dev/null; then
    echo "pip3 not found. Attempting to install python3-pip..."
    sudo apt-get update
    if [ $? -ne 0 ]; then
        echo "Error: Failed to update package lists. Please check your network and sudo permissions."
        exit 1
    fi
    sudo apt-get install -y python3-pip
    if [ $? -ne 0 ]; then
      echo "Error: Failed to install python3-pip. Please install it manually and try again."
      exit 1
    else
      echo "python3-pip installed successfully."
    fi
  else
    echo "pip3 is already installed: $(pip3 --version)"
  fi

  echo "Checking for python3-venv (required for virtual environment)..."
  if ! dpkg -l | grep -q python3-venv; then
    echo "python3-venv not found. Attempting to install..."
    sudo apt-get update # Already run, but good for safety if script is modified
    sudo apt-get install -y python3-venv
    if [ $? -ne 0 ]; then
      echo "Error: Failed to install python3-venv. Please install it manually and try again."
      exit 1
    else
      echo "python3-venv installed successfully."
    fi
  else
    echo "python3-venv is already installed."
  fi
}

# --- Function to create virtual environment and install Python packages ---
setup_python_venv_and_packages() {
  echo "Setting up Python virtual environment in '$VENV_DIR'..."
  if [ -d "$VENV_DIR" ]; then
    echo "Virtual environment directory '$VENV_DIR' already exists. Skipping creation."
  else
    python3 -m venv "$VENV_DIR"
    if [ $? -ne 0 ]; then
      echo "Error: Failed to create virtual environment."
      exit 1
    else
      echo "Virtual environment created successfully."
    fi
  fi

  echo "Installing Python packages: $PYTHON_PACKAGES into the virtual environment..."
  # Use the pip from the virtual environment
  "$VENV_DIR/bin/pip" install $PYTHON_PACKAGES
  if [ $? -ne 0 ]; then
    echo "Error: Failed to install one or more Python packages: $PYTHON_PACKAGES"
    exit 1
  else
    echo "Python packages installed successfully into the virtual environment."
  fi
}
# --- Main script execution ---
# 1. Ensure pip3 and python3-venv are installed
install_prerequisites_if_needed
# 2. Setup Python virtual environment and install packages
setup_python_venv_and_packages
echo "-----------------------------------------------------"
echo "Initial setup (Python venv, Git) complete. Proceeding with InfluxDB deployment."
echo "-----------------------------------------------------"
# 5. Helm and InfluxDB setup
echo "Starting Helm installation for InfluxDB..."
echo "Release Name: $HELM_RELEASE_NAME"
echo "Chart: $CHART_NAME"
echo "Version: $CHART_VERSION"
echo "Image Repository Override: $IMAGE_REPOSITORY"

if helm install "$HELM_RELEASE_NAME" "$CHART_NAME" --version "$CHART_VERSION" --set image.repository="$IMAGE_REPOSITORY"; then
  echo "Helm install command sent for release $HELM_RELEASE_NAME."
else
  echo "Error: Failed to send Helm install command for $HELM_RELEASE_NAME."
  echo "Please check your Helm and kubectl configuration."
fi

echo "Waiting for pods associated with Helm release '$HELM_RELEASE_NAME' to be ready..."

POD_NAME=""
while [ -z "$POD_NAME" ]; do
  echo "Checking for pod name..."
  POD_NAME=$(kubectl get pods -l "app.kubernetes.io/instance=$HELM_RELEASE_NAME" -o jsonpath='{.items[0].metadata.name}')
  
  if [ -z "$POD_NAME" ]; then
    echo "Pod for release $HELM_RELEASE_NAME not found yet. Waiting for 5 seconds..."
    sleep 5
  else
    echo "Found pod: $POD_NAME"
  fi
done

echo "Waiting for pod $POD_NAME to be ready (timeout: $WAIT_TIMEOUT)..."
if kubectl wait --for=condition=ready pod/"$POD_NAME" --timeout="$WAIT_TIMEOUT"; then
  echo "Pod $POD_NAME is ready."
else
  echo "Error: Pod $POD_NAME did not become ready within the timeout period."
  echo "Please check the pod status and events using: kubectl describe pod $POD_NAME"
  echo "And check the Helm release status using: helm status $HELM_RELEASE_NAME"
  exit 1
fi

echo "Fetching admin user token from secret '$SECRET_NAME'..."

if ! kubectl get secret "$SECRET_NAME" > /dev/null 2>&1; then
  echo "Error: Secret '$SECRET_NAME' not found."
  exit 1
fi

INFLUXDB_TOKEN=$(kubectl get secret "$SECRET_NAME" -o jsonpath="{.data.$TOKEN_KEY}" | base64 --decode)

if [ -z "$INFLUXDB_TOKEN" ]; then
  echo "Error: Failed to fetch or decode the '$TOKEN_KEY' from secret '$SECRET_NAME'."
  exit 1
fi

echo "Admin user token fetched successfully."

echo "Attempting to create InfluxDB bucket '$BUCKET_NAME' in organization '$ORG_NAME' using pod $POD_NAME..."

if kubectl exec "$POD_NAME" -- influx bucket create \
  --name "$BUCKET_NAME" \
  --org "$ORG_NAME" \
  --token "$INFLUXDB_TOKEN"; then
  echo "-----------------------------------------------------"
  echo "SUCCESS: All steps completed."
  echo "  - Python prerequisites (pip3, venv) and virtual environment set up."
  echo "  - Python packages (pandas, influxdb_client) installed into venv."
  echo "  - Helm release '$HELM_RELEASE_NAME' deployed."
  echo "  - Associated pod '$POD_NAME' is ready."
  echo "  - InfluxDB bucket '$BUCKET_NAME' created in organization '$ORG_NAME'."
  echo ""
  echo "To use the installed Python packages, activate the virtual environment:"
  echo "  source $VENV_DIR/bin/activate"
  echo "-----------------------------------------------------"
else
  echo "Error: Failed to create InfluxDB bucket '$BUCKET_NAME'."
  echo "Please check the InfluxDB pod logs for more details: kubectl logs $POD_NAME"
fi
echo ""
kubectl port-forward svc/my-release-influxdb 8086:8086 & source $VENV_DIR/bin/activate &python3 insert.py $INFLUXDB_TOKEN
kubectl exec -it $POD_NAME -- influx query  'from(bucket: "UEData") |> range(start: -1000d)' -o primary -t $INFLUXDB_TOKEN
exit 0
