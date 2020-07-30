# terraform-kubernetes-hcloud-csi-driver
A simple module to provision the [Hetzner Container Storage Interface Driver](https://github.com/hetznercloud/csi-driver/) within a Kubernetes cluster running on Hetzner Cloud. See the variables file for the available configuration options. Please note that this module **requires Kubernetes 1.15 or newer**.

### **Prerequisites**

Requires cluster nodes be prior [initialized by a cloud-controller-manager](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/#taint-based-evictions). You can use the [terraform-kubernetes-hcloud-controller-manager](https://github.com/colinwilson/terraform-kubernetes-hcloud-controller-manager) module to initialize your cluster nodes.

### **Deploy Test Persistent Volume**

Verify everything is working, create a persistent volume claim and a pod which uses that volume:

```
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: csi-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: hcloud-volumes
---
kind: Pod
apiVersion: v1
metadata:
  name: my-csi-app
spec:
  containers:
    - name: my-frontend
      image: busybox
      volumeMounts:
      - mountPath: "/data"
        name: my-csi-volume
      command: [ "sleep", "1000000" ]
  volumes:
    - name: my-csi-volume
      persistentVolumeClaim:
        claimName: csi-pvc
```

Once the pod is ready, exec a shell and check that your volume is mounted at `/data`.

```
kubectl exec -it my-csi-app -- /bin/sh
```