/*
Copyright 2024 XDC Network.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	"context"
	"fmt"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	xdcv1alpha1 "github.com/XinFinOrg/xdc-node-setup/k8s/operator/api/v1alpha1"
)

const (
	// FinalizerName is the finalizer for XDCNode resources
	FinalizerName = "xdcnode.xdc.network/finalizer"

	// RequeueAfter is the default requeue duration
	RequeueAfter = 30 * time.Second

	// SyncStatusRequeueAfter is the requeue duration for sync status updates
	SyncStatusRequeueAfter = 60 * time.Second
)

// XDCNodeReconciler reconciles a XDCNode object
type XDCNodeReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=xdc.network,resources=xdcnodes,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=xdc.network,resources=xdcnodes/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=xdc.network,resources=xdcnodes/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=statefulsets,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=configmaps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=persistentvolumeclaims,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=pods,verbs=get;list;watch
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;create;update;patch;delete

// Reconcile is the main reconciliation loop for XDCNode resources
func (r *XDCNodeReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)
	logger.Info("Reconciling XDCNode", "namespace", req.Namespace, "name", req.Name)

	// Fetch the XDCNode instance
	xdcNode := &xdcv1alpha1.XDCNode{}
	if err := r.Get(ctx, req.NamespacedName, xdcNode); err != nil {
		if errors.IsNotFound(err) {
			logger.Info("XDCNode resource not found, skipping reconciliation")
			return ctrl.Result{}, nil
		}
		logger.Error(err, "Failed to get XDCNode")
		return ctrl.Result{}, err
	}

	// Handle deletion
	if !xdcNode.ObjectMeta.DeletionTimestamp.IsZero() {
		return r.handleDeletion(ctx, xdcNode)
	}

	// Add finalizer if not present
	if !controllerutil.ContainsFinalizer(xdcNode, FinalizerName) {
		controllerutil.AddFinalizer(xdcNode, FinalizerName)
		if err := r.Update(ctx, xdcNode); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Update status to Creating if Pending
	if xdcNode.Status.Phase == "" || xdcNode.Status.Phase == xdcv1alpha1.NodePhasePending {
		xdcNode.Status.Phase = xdcv1alpha1.NodePhaseCreating
		if err := r.Status().Update(ctx, xdcNode); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Reconcile ConfigMap
	if err := r.reconcileConfigMap(ctx, xdcNode); err != nil {
		logger.Error(err, "Failed to reconcile ConfigMap")
		return ctrl.Result{}, err
	}

	// Reconcile Service
	if err := r.reconcileService(ctx, xdcNode); err != nil {
		logger.Error(err, "Failed to reconcile Service")
		return ctrl.Result{}, err
	}

	// Reconcile StatefulSet
	if err := r.reconcileStatefulSet(ctx, xdcNode); err != nil {
		logger.Error(err, "Failed to reconcile StatefulSet")
		return ctrl.Result{}, err
	}

	// Reconcile Ingress (if enabled)
	if xdcNode.Spec.Ingress.Enabled {
		if err := r.reconcileIngress(ctx, xdcNode); err != nil {
			logger.Error(err, "Failed to reconcile Ingress")
			return ctrl.Result{}, err
		}
	}

	// Update sync status
	if err := r.updateSyncStatus(ctx, xdcNode); err != nil {
		logger.Error(err, "Failed to update sync status")
		// Don't return error, continue with reconciliation
	}

	// Update final status
	if err := r.updateStatus(ctx, xdcNode); err != nil {
		logger.Error(err, "Failed to update status")
		return ctrl.Result{}, err
	}

	logger.Info("Successfully reconciled XDCNode")
	return ctrl.Result{RequeueAfter: SyncStatusRequeueAfter}, nil
}

// handleDeletion handles the deletion of an XDCNode resource
func (r *XDCNodeReconciler) handleDeletion(ctx context.Context, xdcNode *xdcv1alpha1.XDCNode) (ctrl.Result, error) {
	logger := log.FromContext(ctx)
	logger.Info("Handling deletion of XDCNode")

	// Update status to Terminating
	xdcNode.Status.Phase = xdcv1alpha1.NodePhaseTerminating
	if err := r.Status().Update(ctx, xdcNode); err != nil {
		return ctrl.Result{}, err
	}

	// Perform cleanup logic here
	// The StatefulSet, Service, ConfigMap will be garbage collected
	// due to owner references

	// Remove finalizer
	controllerutil.RemoveFinalizer(xdcNode, FinalizerName)
	if err := r.Update(ctx, xdcNode); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

// reconcileConfigMap ensures the ConfigMap exists with correct configuration
func (r *XDCNodeReconciler) reconcileConfigMap(ctx context.Context, xdcNode *xdcv1alpha1.XDCNode) error {
	logger := log.FromContext(ctx)

	configMap := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      xdcNode.Name + "-config",
			Namespace: xdcNode.Namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, configMap, func() error {
		if err := controllerutil.SetControllerReference(xdcNode, configMap, r.Scheme); err != nil {
			return err
		}

		configMap.Labels = r.getLabels(xdcNode)
		configMap.Data = map[string]string{
			"XDC_NETWORK":   xdcNode.Spec.Network,
			"XDC_CLIENT":    xdcNode.Spec.Client,
			"XDC_NODE_TYPE": xdcNode.Spec.NodeType,
		}

		return nil
	})

	if err != nil {
		return err
	}

	logger.Info("ConfigMap reconciled", "name", configMap.Name)
	return nil
}

// reconcileService ensures the Service exists
func (r *XDCNodeReconciler) reconcileService(ctx context.Context, xdcNode *xdcv1alpha1.XDCNode) error {
	logger := log.FromContext(ctx)

	service := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      xdcNode.Name,
			Namespace: xdcNode.Namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, service, func() error {
		if err := controllerutil.SetControllerReference(xdcNode, service, r.Scheme); err != nil {
			return err
		}

		service.Labels = r.getLabels(xdcNode)
		if xdcNode.Spec.Service.Annotations != nil {
			service.Annotations = xdcNode.Spec.Service.Annotations
		}

		service.Spec.Selector = r.getLabels(xdcNode)
		service.Spec.Type = xdcNode.Spec.Service.Type

		// Define ports
		ports := []corev1.ServicePort{
			{
				Name:       "p2p-tcp",
				Port:       xdcNode.Spec.P2P.Port,
				TargetPort: intstr.FromInt(int(xdcNode.Spec.P2P.Port)),
				Protocol:   corev1.ProtocolTCP,
			},
			{
				Name:       "p2p-udp",
				Port:       xdcNode.Spec.P2P.Port,
				TargetPort: intstr.FromInt(int(xdcNode.Spec.P2P.Port)),
				Protocol:   corev1.ProtocolUDP,
			},
		}

		if xdcNode.Spec.RPC.Enabled {
			ports = append(ports, corev1.ServicePort{
				Name:       "rpc",
				Port:       xdcNode.Spec.RPC.Port,
				TargetPort: intstr.FromInt(int(xdcNode.Spec.RPC.Port)),
				Protocol:   corev1.ProtocolTCP,
			})
		}

		if xdcNode.Spec.WebSocket.Enabled {
			ports = append(ports, corev1.ServicePort{
				Name:       "ws",
				Port:       xdcNode.Spec.WebSocket.Port,
				TargetPort: intstr.FromInt(int(xdcNode.Spec.WebSocket.Port)),
				Protocol:   corev1.ProtocolTCP,
			})
		}

		if xdcNode.Spec.Metrics.Enabled {
			ports = append(ports, corev1.ServicePort{
				Name:       "metrics",
				Port:       xdcNode.Spec.Metrics.Port,
				TargetPort: intstr.FromInt(int(xdcNode.Spec.Metrics.Port)),
				Protocol:   corev1.ProtocolTCP,
			})
		}

		service.Spec.Ports = ports

		return nil
	})

	if err != nil {
		return err
	}

	logger.Info("Service reconciled", "name", service.Name)
	return nil
}

// reconcileStatefulSet ensures the StatefulSet exists
func (r *XDCNodeReconciler) reconcileStatefulSet(ctx context.Context, xdcNode *xdcv1alpha1.XDCNode) error {
	logger := log.FromContext(ctx)

	sts := &appsv1.StatefulSet{
		ObjectMeta: metav1.ObjectMeta{
			Name:      xdcNode.Name,
			Namespace: xdcNode.Namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, sts, func() error {
		if err := controllerutil.SetControllerReference(xdcNode, sts, r.Scheme); err != nil {
			return err
		}

		labels := r.getLabels(xdcNode)
		sts.Labels = labels

		replicas := xdcNode.Spec.Replicas
		if replicas == 0 {
			replicas = 1
		}

		sts.Spec = appsv1.StatefulSetSpec{
			Replicas:    &replicas,
			ServiceName: xdcNode.Name,
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: labels,
				},
				Spec: r.buildPodSpec(xdcNode),
			},
		}

		// Add volume claim templates if storage is enabled
		if xdcNode.Spec.Storage.Enabled {
			sts.Spec.VolumeClaimTemplates = []corev1.PersistentVolumeClaim{
				{
					ObjectMeta: metav1.ObjectMeta{
						Name: "data",
					},
					Spec: corev1.PersistentVolumeClaimSpec{
						AccessModes: []corev1.PersistentVolumeAccessMode{
							xdcNode.Spec.Storage.AccessMode,
						},
						Resources: corev1.VolumeResourceRequirements{
							Requests: corev1.ResourceList{
								corev1.ResourceStorage: resource.MustParse(xdcNode.Spec.Storage.Size),
							},
						},
						StorageClassName: &xdcNode.Spec.Storage.StorageClass,
					},
				},
			}
		}

		return nil
	})

	if err != nil {
		return err
	}

	logger.Info("StatefulSet reconciled", "name", sts.Name)
	return nil
}

// reconcileIngress ensures the Ingress exists (if enabled)
func (r *XDCNodeReconciler) reconcileIngress(ctx context.Context, xdcNode *xdcv1alpha1.XDCNode) error {
	logger := log.FromContext(ctx)

	ingress := &networkingv1.Ingress{
		ObjectMeta: metav1.ObjectMeta{
			Name:      xdcNode.Name,
			Namespace: xdcNode.Namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, ingress, func() error {
		if err := controllerutil.SetControllerReference(xdcNode, ingress, r.Scheme); err != nil {
			return err
		}

		ingress.Labels = r.getLabels(xdcNode)
		if xdcNode.Spec.Ingress.Annotations != nil {
			ingress.Annotations = xdcNode.Spec.Ingress.Annotations
		}

		pathType := networkingv1.PathTypePrefix
		ingress.Spec = networkingv1.IngressSpec{
			IngressClassName: &xdcNode.Spec.Ingress.ClassName,
			Rules: []networkingv1.IngressRule{
				{
					Host: xdcNode.Spec.Ingress.Host,
					IngressRuleValue: networkingv1.IngressRuleValue{
						HTTP: &networkingv1.HTTPIngressRuleValue{
							Paths: []networkingv1.HTTPIngressPath{
								{
									Path:     "/",
									PathType: &pathType,
									Backend: networkingv1.IngressBackend{
										Service: &networkingv1.IngressServiceBackend{
											Name: xdcNode.Name,
											Port: networkingv1.ServiceBackendPort{
												Number: xdcNode.Spec.RPC.Port,
											},
										},
									},
								},
							},
						},
					},
				},
			},
		}

		if xdcNode.Spec.Ingress.TLS && xdcNode.Spec.Ingress.TLSSecretName != "" {
			ingress.Spec.TLS = []networkingv1.IngressTLS{
				{
					Hosts:      []string{xdcNode.Spec.Ingress.Host},
					SecretName: xdcNode.Spec.Ingress.TLSSecretName,
				},
			}
		}

		return nil
	})

	if err != nil {
		return err
	}

	logger.Info("Ingress reconciled", "name", ingress.Name)
	return nil
}

// buildPodSpec builds the pod specification for the XDC node
func (r *XDCNodeReconciler) buildPodSpec(xdcNode *xdcv1alpha1.XDCNode) corev1.PodSpec {
	image := xdcNode.Spec.Image.Repository + ":" + xdcNode.Spec.Image.Tag
	if xdcNode.Spec.Client == "erigon-xdc" {
		image = "xinfinorg/erigon-xdc:" + xdcNode.Spec.Image.Tag
	}

	args := r.buildNodeArgs(xdcNode)

	container := corev1.Container{
		Name:            "xdc-node",
		Image:           image,
		ImagePullPolicy: xdcNode.Spec.Image.PullPolicy,
		Args:            args,
		Ports: []corev1.ContainerPort{
			{Name: "p2p-tcp", ContainerPort: xdcNode.Spec.P2P.Port, Protocol: corev1.ProtocolTCP},
			{Name: "p2p-udp", ContainerPort: xdcNode.Spec.P2P.Port, Protocol: corev1.ProtocolUDP},
		},
		Resources: xdcNode.Spec.Resources,
		VolumeMounts: []corev1.VolumeMount{
			{Name: "data", MountPath: "/xdcchain"},
		},
		EnvFrom: []corev1.EnvFromSource{
			{
				ConfigMapRef: &corev1.ConfigMapEnvSource{
					LocalObjectReference: corev1.LocalObjectReference{
						Name: xdcNode.Name + "-config",
					},
				},
			},
		},
	}

	// Add RPC port
	if xdcNode.Spec.RPC.Enabled {
		container.Ports = append(container.Ports, corev1.ContainerPort{
			Name: "rpc", ContainerPort: xdcNode.Spec.RPC.Port, Protocol: corev1.ProtocolTCP,
		})
	}

	// Add WebSocket port
	if xdcNode.Spec.WebSocket.Enabled {
		container.Ports = append(container.Ports, corev1.ContainerPort{
			Name: "ws", ContainerPort: xdcNode.Spec.WebSocket.Port, Protocol: corev1.ProtocolTCP,
		})
	}

	// Add metrics port
	if xdcNode.Spec.Metrics.Enabled {
		container.Ports = append(container.Ports, corev1.ContainerPort{
			Name: "metrics", ContainerPort: xdcNode.Spec.Metrics.Port, Protocol: corev1.ProtocolTCP,
		})
	}

	// Add liveness and readiness probes
	container.LivenessProbe = &corev1.Probe{
		ProbeHandler: corev1.ProbeHandler{
			HTTPGet: &corev1.HTTPGetAction{
				Path: "/",
				Port: intstr.FromInt(int(xdcNode.Spec.RPC.Port)),
			},
		},
		InitialDelaySeconds: 60,
		PeriodSeconds:       30,
		TimeoutSeconds:      10,
		FailureThreshold:    3,
	}

	container.ReadinessProbe = &corev1.Probe{
		ProbeHandler: corev1.ProbeHandler{
			HTTPGet: &corev1.HTTPGetAction{
				Path: "/",
				Port: intstr.FromInt(int(xdcNode.Spec.RPC.Port)),
			},
		},
		InitialDelaySeconds: 30,
		PeriodSeconds:       10,
		TimeoutSeconds:      5,
		FailureThreshold:    3,
	}

	podSpec := corev1.PodSpec{
		Containers:   []corev1.Container{container},
		NodeSelector: xdcNode.Spec.NodeSelector,
		Tolerations:  xdcNode.Spec.Tolerations,
		Affinity:     xdcNode.Spec.Affinity,
	}

	return podSpec
}

// buildNodeArgs builds the command line arguments for the XDC node
func (r *XDCNodeReconciler) buildNodeArgs(xdcNode *xdcv1alpha1.XDCNode) []string {
	args := []string{
		"--" + xdcNode.Spec.Network,
		"--datadir=/xdcchain",
		fmt.Sprintf("--port=%d", xdcNode.Spec.P2P.Port),
		fmt.Sprintf("--maxpeers=%d", xdcNode.Spec.P2P.MaxPeers),
		fmt.Sprintf("--cache=%d", xdcNode.Spec.Sync.CacheSize),
	}

	// RPC configuration
	if xdcNode.Spec.RPC.Enabled {
		args = append(args,
			"--http",
			"--http.addr=0.0.0.0",
			fmt.Sprintf("--http.port=%d", xdcNode.Spec.RPC.Port),
			"--http.api="+joinStrings(xdcNode.Spec.RPC.API, ","),
			"--http.corsdomain="+xdcNode.Spec.RPC.CorsDomain,
			"--http.vhosts="+xdcNode.Spec.RPC.VHosts,
		)
	}

	// WebSocket configuration
	if xdcNode.Spec.WebSocket.Enabled {
		args = append(args,
			"--ws",
			"--ws.addr=0.0.0.0",
			fmt.Sprintf("--ws.port=%d", xdcNode.Spec.WebSocket.Port),
			"--ws.api="+joinStrings(xdcNode.Spec.WebSocket.API, ","),
		)
	}

	// Metrics configuration
	if xdcNode.Spec.Metrics.Enabled {
		args = append(args,
			"--metrics",
			"--metrics.addr=0.0.0.0",
			fmt.Sprintf("--metrics.port=%d", xdcNode.Spec.Metrics.Port),
		)
	}

	// Add extra flags
	args = append(args, xdcNode.Spec.ExtraFlags...)

	return args
}

// updateSyncStatus updates the sync status by querying the node RPC
func (r *XDCNodeReconciler) updateSyncStatus(ctx context.Context, xdcNode *xdcv1alpha1.XDCNode) error {
	// TODO: Implement RPC call to get sync status
	// This is a placeholder - in production, you would:
	// 1. Get the pod IP
	// 2. Make JSON-RPC calls to eth_syncing, net_peerCount, etc.
	// 3. Update the status accordingly

	return nil
}

// updateStatus updates the overall status of the XDCNode
func (r *XDCNodeReconciler) updateStatus(ctx context.Context, xdcNode *xdcv1alpha1.XDCNode) error {
	// Check if StatefulSet is ready
	sts := &appsv1.StatefulSet{}
	if err := r.Get(ctx, types.NamespacedName{Name: xdcNode.Name, Namespace: xdcNode.Namespace}, sts); err != nil {
		if !errors.IsNotFound(err) {
			return err
		}
		xdcNode.Status.Phase = xdcv1alpha1.NodePhaseCreating
	} else if sts.Status.ReadyReplicas == *sts.Spec.Replicas {
		// Check sync status
		if xdcNode.Status.SyncStatus.Syncing {
			xdcNode.Status.Phase = xdcv1alpha1.NodePhaseSyncing
		} else {
			xdcNode.Status.Phase = xdcv1alpha1.NodePhaseReady
		}
	} else {
		xdcNode.Status.Phase = xdcv1alpha1.NodePhaseCreating
	}

	// Update endpoints
	svc := &corev1.Service{}
	if err := r.Get(ctx, types.NamespacedName{Name: xdcNode.Name, Namespace: xdcNode.Namespace}, svc); err == nil {
		xdcNode.Status.Endpoints.RPC = fmt.Sprintf("http://%s:%d", svc.Spec.ClusterIP, xdcNode.Spec.RPC.Port)
		xdcNode.Status.Endpoints.P2P = fmt.Sprintf("%s:%d", svc.Spec.ClusterIP, xdcNode.Spec.P2P.Port)
		if xdcNode.Spec.Metrics.Enabled {
			xdcNode.Status.Endpoints.Metrics = fmt.Sprintf("http://%s:%d/metrics", svc.Spec.ClusterIP, xdcNode.Spec.Metrics.Port)
		}
	}

	// Update observed generation
	xdcNode.Status.ObservedGeneration = xdcNode.Generation

	// Update last updated timestamp
	now := metav1.Now()
	xdcNode.Status.LastUpdated = &now

	return r.Status().Update(ctx, xdcNode)
}

// getLabels returns the labels for XDCNode resources
func (r *XDCNodeReconciler) getLabels(xdcNode *xdcv1alpha1.XDCNode) map[string]string {
	return map[string]string{
		"app.kubernetes.io/name":       "xdc-node",
		"app.kubernetes.io/instance":   xdcNode.Name,
		"app.kubernetes.io/managed-by": "xdc-operator",
		"xdc.network/network":          xdcNode.Spec.Network,
		"xdc.network/client":           xdcNode.Spec.Client,
		"xdc.network/node-type":        xdcNode.Spec.NodeType,
	}
}

// joinStrings joins a slice of strings with a separator
func joinStrings(s []string, sep string) string {
	result := ""
	for i, str := range s {
		if i > 0 {
			result += sep
		}
		result += str
	}
	return result
}

// SetupWithManager sets up the controller with the Manager.
func (r *XDCNodeReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&xdcv1alpha1.XDCNode{}).
		Owns(&appsv1.StatefulSet{}).
		Owns(&corev1.Service{}).
		Owns(&corev1.ConfigMap{}).
		Owns(&networkingv1.Ingress{}).
		Complete(r)
}
